//SPDX-License-Identifier: None
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

interface Factory {
    function owner() external returns (address);
}

interface IERC20WithDecimals {
    function decimals() external view returns (uint8);
}

// All amountPerSec and all internal numbers use 20 decimals, these are converted to the right decimal on withdrawal/deposit
// The reason for that is to minimize precision errors caused by integer math on tokens with low decimals (eg: USDC)

/*
    It's possible to optimize further by making all multiplications against totalPaidPerSec[from] unchecked,
    however this introduces an attack vector that makes it possible to steal other people's money by overflowing these operations.
    The gist is that this attack would require sending >1bn txs calling createStream() so it's very unrealistic.
    However we don't make that optimization.

    This same attack also makes it possible to increase totalPaidPerSec[from] so much that any withdraw() calls from payees will revert
    however this only affects payees of the attacker and there will be plenty of time to withdraw() your money when the attack starts,
    so we apply this optimization. The only point of this would be to prevent the people you are paying from withrawing their earnings,
    but you can't get the money back and you'll need to spend a very long time and resources to execute.

    On Ethereum this attack would require owning all full blocks for 243 consecutive days.
*/

// Invariant through the whole contract: lastPayerUpdate[anyone] <= block.timestamp
// Reason: timestamps can't go back in time (https://github.com/ethereum/go-ethereum/blob/master/consensus/ethash/consensus.go#L274)

contract LlamaPay {
    mapping (bytes32 => uint) public streamToStart;
    mapping (address => uint) public totalPaidPerSec;
    mapping (address => uint) public lastPayerUpdate;
    mapping (address => uint) public balances;
    IERC20 immutable public token;
    address immutable public factory;
    uint immutable public DECIMALS_DIVISOR;

    event StreamCreated(address indexed from, address indexed to, uint amountPerSec, bytes32 streamId);
    event StreamCancelled(address indexed from, address indexed to, uint amountPerSec, bytes32 streamId);

    constructor(address _token, address _factory){
        token = IERC20(_token);
        factory = _factory;
        uint8 tokenDecimals = IERC20WithDecimals(_token).decimals();
        DECIMALS_DIVISOR = 10**(20 - tokenDecimals);
    }

    function getStreamId(address from, address to, uint amountPerSec) public pure returns (bytes32){
        return keccak256(abi.encodePacked(from, to, amountPerSec));
    }

    function updateBalances(address payer) private {
        uint delta;
        unchecked {
            delta = block.timestamp - lastPayerUpdate[payer];
        }
        uint totalPaid = delta * totalPaidPerSec[payer]; // OPTIMIZATION: unchecked
        balances[payer] -= totalPaid; // implicit check that balance >= totalPaid
        lastPayerUpdate[payer] = block.timestamp;
    }

    function createStream(address to, uint amountPerSec) public {
        bytes32 streamId = getStreamId(msg.sender, to, amountPerSec);
        // this checks that even if:
        // - each person earns 10B/sec
        // - each person will be earning for 1000 years
        // - there are 1B people earning (requires 1B txs)
        // there won't be an overflow in all those 1k years
        // checking for overflow is important because if there's an overflow later money will be stuck forever as all txs will revert
        // this can be used to rug employees by pushing totalPaidPerSec[from] to a high number, making txs revert
        unchecked {
            require(amountPerSec < type(uint).max/(10e9 * 1e3 * 365 days * 1e9), "no overflow");
        }
        require(amountPerSec > 0, "amountPerSec can't be 0");
        require(streamToStart[streamId] == 0, "stream already exists");
        streamToStart[streamId] = block.timestamp;
        updateBalances(msg.sender); // can't create a new stream unless there's no debt
        totalPaidPerSec[msg.sender] += amountPerSec; // OPTIMIZATION: unchecked
        emit StreamCreated(msg.sender, to, amountPerSec, streamId);
    }

    function cancelStream(address to, uint amountPerSec) public {
        withdraw(msg.sender, to, amountPerSec);
        bytes32 streamId = getStreamId(msg.sender, to, amountPerSec);
        streamToStart[streamId] = 0;
        unchecked{
            totalPaidPerSec[msg.sender] -= amountPerSec;
        }
        emit StreamCancelled(msg.sender, to, amountPerSec, streamId);
    }

    /*
        proof that lastUpdate < block.timestamp:

        let's start by assuming the opposite, that lastUpdate > block.timestamp, and then we'll prove that this is impossible
        lastUpdate > block.timestamp
            -> timePaid = lastUpdate - lastPayerUpdate[from] > block.timestamp - lastPayerUpdate[from] = payerDelta
            -> timePaid > payerDelta
            -> payerBalance = timePaid * totalPaidPerSec[from] > payerDelta * totalPaidPerSec[from] = totalPayerPayment
            -> payerBalance > totalPayerPayment
        but this last statement is impossible because if it were true we'd have gone into the first if branch!
    */
    /*
        proof that totalPaidPerSec[from] != 0:

        totalPaidPerSec[from] is a sum of uint that are different from zero (since we test that on createStream())
        and we test that there's at least one stream active with `streamToStart[streamId] != 0`,
        so it's a sum of one or more elements that are higher than zero, thus it can never be zero
    */

    // Make it possible to withdraw on behalf of others, important for people that don't have a metamask wallet (eg: cex address, trustwallet...)
    function withdraw(address from, address to, uint amountPerSec) public {
        bytes32 streamId = getStreamId(from, to, amountPerSec);
        require(streamToStart[streamId] != 0, "stream doesn't exist");

        uint payerDelta = block.timestamp - lastPayerUpdate[from];
        uint totalPayerPayment = payerDelta * totalPaidPerSec[from];
        uint payerBalance = balances[from];
        uint lastUpdate;
        if(payerBalance >= totalPayerPayment){
            unchecked {
                balances[from] = payerBalance - totalPayerPayment;   
            }
            lastUpdate = block.timestamp;
        } else {
            // invariant: totalPaidPerSec[from] != 0
            unchecked {
                uint timePaid = payerBalance/totalPaidPerSec[from];
                lastUpdate = lastPayerUpdate[from] + timePaid;
                // invariant: lastUpdate < block.timestamp (we need to maintain it)
                balances[from] = payerBalance % totalPaidPerSec[from];
            }
        }
        lastPayerUpdate[from] = lastUpdate;
        uint delta = lastUpdate - streamToStart[streamId];
        streamToStart[streamId] = lastUpdate;
        token.transfer(to, (delta*amountPerSec)/DECIMALS_DIVISOR);
    }

    function modifyStream(address oldTo, uint oldAmountPerSec, address to, uint amountPerSec) external {
        // Can be optimized but I don't think extra complexity is worth it
        cancelStream(oldTo, oldAmountPerSec);
        createStream(to, amountPerSec);
    }

    function deposit(uint amount) external {
        balances[msg.sender] += amount * DECIMALS_DIVISOR;
        token.transferFrom(msg.sender, address(this), amount);
    }

    function withdrawPayer(uint amount) external {
        balances[msg.sender] -= amount; // implicit check that balance > amount
        uint delta;
        unchecked {
            delta = block.timestamp - lastPayerUpdate[msg.sender];
        }
        require(balances[msg.sender] >= delta*totalPaidPerSec[msg.sender], "pls no rug");
        token.transfer(msg.sender, amount/DECIMALS_DIVISOR);
    }

    function withdrawPayerAll() external {
        uint delta;
        unchecked {
            delta = block.timestamp - lastPayerUpdate[msg.sender];
        }
        balances[msg.sender] -= delta*totalPaidPerSec[msg.sender];
        token.transfer(msg.sender, balances[msg.sender]/DECIMALS_DIVISOR);
    }

    function getPayerBalance(address payer) external view returns (int) {
        int balance = int(balances[payer]);
        uint delta = block.timestamp - lastPayerUpdate[payer];
        return balance - int(delta*totalPaidPerSec[payer]);
    }

    // Performs an arbitrary call
    // This will be under a heavy timelock and only used in case something goes very wrong (eg: with yield engine)
    function emergencyRug(address to, uint amount) external {
        require(Factory(factory).owner() == msg.sender, "not owner");
        if(amount == 0){
            amount = token.balanceOf(address(this));
        }
        token.transfer(to, amount);
    }
}

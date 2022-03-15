//SPDX-License-Identifier: None
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Adapter.sol";

contract LlamaPay is Ownable {
    mapping (bytes32 => uint) public streamToStart;
    mapping (address => uint) public totalPaidPerSec;
    mapping (address => uint) public lastPayerUpdate;
    mapping (address => uint) public balances;
    mapping (address => uint) public yieldEarnedPerToken;
    mapping (address => uint) public paidBalance;
    mapping (address => uint) public lastPricePerShare;
    IERC20 immutable public token;
    address immutable public vault;
    address immutable public adapter;

    constructor(address _token, address _adapter, address _vault){
        token = IERC20(_token);
        adapter = _adapter;
        vault = _vault;
        _refreshSetup(_adapter, _token, _vault);
    }

    function getStreamId(address from, address to, uint amountPerSec) public pure returns (bytes32){
        return keccak256(abi.encodePacked(from, to, amountPerSec));
    }

    function getPricePerShare() private view returns (uint) {
        return Adapter(adapter).pricePerShare(vault);
    }

    function updateBalances(address payer) private {
        uint delta;
        unchecked {
            delta = block.timestamp - lastPayerUpdate[payer];
        }
        uint totalPaid = delta * totalPaidPerSec[payer];
        balances[payer] -= totalPaid;
        lastPayerUpdate[payer] = block.timestamp;

        uint lastPrice = lastPricePerShare[payer];
        uint currentPrice = Adapter(adapter).pricePerShare(vault);
        if(lastPrice == 0){
            lastPrice = currentPrice;
        }
        if(currentPrice >= lastPrice) {
            // no need to worry about currentPrice = 0 because that means that all money is gone
            balances[payer] = (balances[payer]*currentPrice)/lastPrice;
            uint profitsFromPaid = ((totalPaid*currentPrice)/lastPrice - totalPaid)/2; // assumes profits are strictly increasing
            balances[payer] += profitsFromPaid;
            uint yieldOnOldCoins = ((paidBalance[payer]*currentPrice)/lastPrice) - paidBalance[payer];
            yieldEarnedPerToken[payer] += (profitsFromPaid + yieldOnOldCoins)/paidBalance[payer];
            paidBalance[payer] += yieldOnOldCoins + profitsFromPaid + totalPaid;
            lastPricePerShare[payer] = currentPrice;
        }
    }

    function createStream(address to, uint amountPerSec) public {
        bytes32 streamId = getStreamId(msg.sender, to, amountPerSec);
        // this checks that even if:
        // - token has 18 decimals
        // - each person earns 10B/yr
        // - each person will be earning for 1000 years
        // - there are 1B people earning (requires 1B txs)
        // there won't be an overflow in all those 1k years
        // checking for overflow is important because if there's an overflow later money will be stuck forever as all txs will revert
        unchecked {
            require(amountPerSec < type(uint).max/(10e9 * 1e3 * 365 days * 1e9), "no overflow");
        }
        require(amountPerSec > 0, "amountPerSec can't be 0");
        require(streamToStart[streamId] == 0, "stream already exists");
        streamToStart[streamId] = block.timestamp;
        updateBalances(msg.sender); // can't create a new stream unless there's no debt
        totalPaidPerSec[msg.sender] += amountPerSec;
    }

    function cancelStream(address to, uint amountPerSec) public {
        withdraw(msg.sender, to, amountPerSec);
        bytes32 streamId = getStreamId(msg.sender, to, amountPerSec);
        streamToStart[streamId] = 0;
        unchecked{
            totalPaidPerSec[msg.sender] -= amountPerSec;
        }
    }

    // Make it possible to withdraw on behalf of others, important for people that don't have a metamask wallet (eg: cex address, trustwallet...)
    function withdraw(address from, address to, uint amountPerSec) public {
        bytes32 streamId = getStreamId(from, to, amountPerSec);
        require(streamToStart[streamId] != 0, "stream doesn't exist");

        uint payerDelta = block.timestamp - lastPayerUpdate[from];
        uint totalPayerPayment = payerDelta * totalPaidPerSec[from];
        uint payerBalance = balances[from];
        if(payerBalance >= totalPayerPayment){
            balances[from] -= totalPayerPayment;
            lastPayerUpdate[from] = block.timestamp;
        } else {
            // invariant: totalPaidPerSec[from] != 0
            unchecked {
                uint timePaid = payerBalance/totalPaidPerSec[from];
                lastPayerUpdate[from] += timePaid;
                // invariant: lastPayerUpdate[from] < block.timestamp
                balances[from] = payerBalance % totalPaidPerSec[from];
            }
        }
        uint lastUpdate = lastPayerUpdate[from];
        uint delta = lastUpdate - streamToStart[streamId];
        streamToStart[streamId] = lastUpdate;
        paidBalance[from] -= delta*amountPerSec;
        token.transfer(to, delta*amountPerSec);
    }

    function modify(address oldTo, uint oldAmountPerSec, address to, uint amountPerSec) external {
        cancelStream(oldTo, oldAmountPerSec);
        createStream(to, amountPerSec);
    }

    function deposit(uint amount) external {
        token.transferFrom(msg.sender, address(this), amount);
        (bool success,) = adapter.delegatecall(
            abi.encodeWithSelector(Adapter.deposit.selector, vault, amount)
        );
        require(success, "deposit() failed");
        balances[msg.sender] += amount;
    }

    function withdrawPayer(uint amount) external {
        balances[msg.sender] -= amount; // implicit check that balance > amount
        uint delta;
        unchecked {
            delta = block.timestamp - lastPayerUpdate[msg.sender]; // timestamps can't go back in time (https://github.com/ethereum/go-ethereum/blob/master/consensus/ethash/consensus.go#L274)
        }
        require(delta*totalPaidPerSec[msg.sender] >= balances[msg.sender], "pls no rug");
        uint prevBalance = token.balanceOf(address(this));
        withdrawFromVault(amount/lastPricePerShare[msg.sender]);
        uint newBalance = token.balanceOf(address(this));
        token.transfer(msg.sender, newBalance-prevBalance);
    }

    function withdrawFromVault(uint amount) private {
        (bool success,) = adapter.delegatecall(
            abi.encodeWithSelector(Adapter.withdraw.selector, vault, amount)
        );
        require(success, "refreshSetup() failed");
    }

    function _refreshSetup(address _adapter, address _token, address _vault) private {
        (bool success,) = _adapter.delegatecall(
            abi.encodeWithSelector(Adapter.refreshSetup.selector, _token, _vault)
        );
        require(success, "refreshSetup() failed");
    }

    function refreshSetup() public {
        _refreshSetup(adapter, address(token), vault);
    }

    // Performs an arbitrary call
    // This will be under a heavy timelock and only used in case something goes very wrong (eg: with yield engine)
    function emergencyAccess(address target, uint value, bytes memory callData) external onlyOwner {
        target.call{value: value}(callData);
    }
}

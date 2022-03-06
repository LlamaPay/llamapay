//SPDX-License-Identifier: None
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "./LlamaPay.sol";

contract LlamaPayFactory {
    mapping(address=>mapping(address=>mapping(address => LlamaPay))) public payContracts;
    mapping(uint => LlamaPay) public payContractsArray;
    uint public payContractsArrayLength;

    event LlamaPayCreated(address token, address adapter, address vault, address llamaPay);

    function createPayContract(address _token, address _adapter, address _vault) external returns (LlamaPay newContract) {
        newContract = new LlamaPay(_token, _adapter, _vault);
        payContracts[_token][_adapter][_vault] = newContract;
        payContractsArray[payContractsArrayLength] = newContract;
        unchecked{
            payContractsArrayLength++;
        }
        emit LlamaPayCreated(_token, _adapter, _vault, address(newContract));
    }
}
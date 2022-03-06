//SPDX-License-Identifier: None
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
  uint8 decimals_;
  constructor(uint8 decimals__) ERC20("a", "b") {
    decimals_ = decimals__;
    _mint(msg.sender, 2**255-1);
  }

  function decimals() public view override returns (uint8) {
    return decimals_;
  }
}
// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

interface BoostAware {
  struct Boost {
    bytes32 ref;
    address token;
    uint256 balance;
    address guard;
    uint256 start;
    uint256 end;
    address owner;
  }
}

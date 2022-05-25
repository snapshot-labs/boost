// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Create2.sol";

contract SingletonFactory {
  function deploy(bytes32 salt, bytes calldata bytecode) external {
    Create2.deploy(0, salt, bytecode);
  }

  function computeAddress(bytes32 salt, bytes32 bytecodeHash) external view returns (address) {
    return Create2.computeAddress(salt, bytecodeHash);
  }
}
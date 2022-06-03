// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

abstract contract BoostGuard {
  function isValid(
    uint256 boostId,
    address recipient,
    uint256 amount
  ) external returns (bool) {
    return getAmount(boostId, recipient) == amount;
  }

  function getAmount(uint256 boostId, address recipient) public virtual returns (uint256);
}

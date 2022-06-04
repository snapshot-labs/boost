// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "./BoostAware.sol";

abstract contract BoostGuard is BoostAware {
  function getAmount(Boost calldata boost, address recipient) public virtual returns (uint256);
}

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@snapshot-labs/boost/contracts/BoostGuard.sol";
import "./BoostGuard.sol";

contract BoostGuardExample is BoostGuard {
  mapping(bytes32 => bool) public enabledRefs;
  address public token;

  constructor(address _token) {
    token = _token;
  }

  function getAmount(Boost calldata boost, address recipient)
    public
    view
    override
    returns (uint256)
  {
    if (!enabledRefs[boost.ref]) revert("Ref not enabled");

    return IERC20(token).balanceOf(recipient) / 100;
  }

  function enableRef(bytes32 ref) public {
    enabledRefs[ref] = true;
  }
}

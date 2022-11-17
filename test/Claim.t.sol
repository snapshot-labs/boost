// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "./Boost.t.sol";

contract BoostClaimTest is BoostTest {

    address public claimer = address(0x4321);

    function testClaimForSingleRecipient() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostId = _createBoost(depositAmount);
        IBoost.Claim memory claim = IBoost.Claim({boostId: boostId, recipient: claimer, amount: 1});
        bytes memory sig = _generateClaimSignature(claim);
        vm.prank(claimer);
        boost.claimTokens(claim, sig);
    }
}
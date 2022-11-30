// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./Boost.t.sol";

contract BoostClaimTest is BoostTest {
    address public constant claimer = address(0x1111);
    address public constant claimer2 = address(0x2222);
    address public constant claimer3 = address(0x3333);

    function testClaimSingleRecipient() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostId = _createBoost(depositAmount);
        IBoost.Claim memory claim = IBoost.Claim({ boostId: boostId, recipient: claimer, amount: 1 });
        vm.expectEmit(true, false, false, true);
        emit TokensClaimed(claim);
        snapStart("ClaimSingle");
        boost.claimTokens(claim, _generateClaimSignature(claim));
        snapEnd();
        assertEq(token.balanceOf(address(boost)), depositAmount - 1);
        assertEq(token.balanceOf(claimer), 1);
    }

    function testClaimMultipleRecipients() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostId = _createBoost(depositAmount);
        IBoost.Claim memory claim = IBoost.Claim({ boostId: boostId, recipient: claimer, amount: 1 });
        IBoost.Claim memory claim2 = IBoost.Claim({ boostId: boostId, recipient: claimer2, amount: 1 });
        IBoost.Claim memory claim3 = IBoost.Claim({ boostId: boostId, recipient: claimer3, amount: 1 });
        boost.claimTokens(claim, _generateClaimSignature(claim));
        boost.claimTokens(claim2, _generateClaimSignature(claim2));
        boost.claimTokens(claim3, _generateClaimSignature(claim3));
        assertEq(token.balanceOf(address(boost)), depositAmount - 3);
        assertEq(token.balanceOf(claimer), 1);
        assertEq(token.balanceOf(claimer2), 1);
        assertEq(token.balanceOf(claimer3), 1);
    }

    function testClaimReusedSignature() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostId = _createBoost(depositAmount);
        IBoost.Claim memory claim = IBoost.Claim({ boostId: boostId, recipient: claimer, amount: 1 });
        bytes memory sig = _generateClaimSignature(claim);
        boost.claimTokens(claim, sig);
        vm.expectRevert(IBoost.RecipientAlreadyClaimed.selector);
        boost.claimTokens(claim, sig);
    }

    function testClaimInvalidSignature() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostId = _createBoost(depositAmount);
        IBoost.Claim memory claim = IBoost.Claim({ boostId: boostId, recipient: claimer, amount: 1 });
        bytes memory sig = _generateClaimSignature(IBoost.Claim({ boostId: boostId, recipient: claimer, amount: 2 }));
        vm.expectRevert(IBoost.InvalidSignature.selector);
        boost.claimTokens(claim, sig);
    }

    function testClaimBoostEnded() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostId = _createBoost(depositAmount);
        IBoost.Claim memory claim = IBoost.Claim({ boostId: boostId, recipient: claimer, amount: 1 });
        bytes memory sig = _generateClaimSignature(claim);
        vm.warp(block.timestamp + 60);
        vm.expectRevert(IBoost.BoostEnded.selector);
        boost.claimTokens(claim, sig);
    }

    function testClaimBoostNotStarted() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostId = boost.nextBoostId();
        IBoost.BoostConfig memory boostConfig = IBoost.BoostConfig({
            strategyURI: strategyURI,
            token: address(token),
            balance: depositAmount,
            guard: guard,
            start: block.timestamp + 60,
            end: block.timestamp + 120,
            owner: owner
        });
        vm.prank(owner);
        boost.createBoost(boostConfig);
        IBoost.Claim memory claim = IBoost.Claim({ boostId: boostId, recipient: claimer, amount: 1 });
        bytes memory sig = _generateClaimSignature(claim);
        vm.expectRevert(abi.encodeWithSelector(IBoost.BoostNotStarted.selector, block.timestamp + 60));
        boost.claimTokens(claim, sig);
    }

    function testClaimBoostDoesntExist() public {
        IBoost.Claim memory claim = IBoost.Claim({ boostId: 1, recipient: claimer, amount: 1 });
        bytes memory sig = _generateClaimSignature(claim);
        vm.expectRevert(IBoost.InsufficientBoostBalance.selector);
        boost.claimTokens(claim, sig);
    }

    function testClaimExceedsBalance() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostId = _createBoost(depositAmount);
        IBoost.Claim memory claim = IBoost.Claim({ boostId: boostId, recipient: claimer, amount: depositAmount + 1 });
        bytes memory sig = _generateClaimSignature(claim);
        vm.expectRevert(IBoost.InsufficientBoostBalance.selector);
        boost.claimTokens(claim, sig);
    }
}

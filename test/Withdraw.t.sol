// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "./Boost.t.sol";

contract BoostWithdrawTest is BoostTest {
    address public constant claimer = address(0x1111);
    address public constant claimer2 = address(0x2222);
    address public constant claimer3 = address(0x3333);

    function testWithdrawAfterBoostExpired() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostId = _createBoost(depositAmount);
        vm.warp(block.timestamp + 60);
        vm.prank(owner);
        boost.withdrawRemainingTokens(boostId, owner);
        assertEq(token.balanceOf(address(boost)), 0);
        assertEq(token.balanceOf(owner), depositAmount);
    }

    function testWithdrawBoostNotOwner() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostId = _createBoost(depositAmount);
        vm.warp(block.timestamp + 60);
        vm.prank(claimer);
        vm.expectRevert(IBoost.OnlyBoostOwner.selector);
        boost.withdrawRemainingTokens(boostId, claimer);
    }

    function testWithdrawBoostNotExpired() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostId = _createBoost(depositAmount);
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(IBoost.BoostNotEnded.selector, block.timestamp + 60));
        boost.withdrawRemainingTokens(boostId, owner);
    }

    function testWithdrawZeroBalance() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostId = _createBoost(depositAmount);
        IBoost.Claim memory claim = IBoost.Claim({ boostId: boostId, recipient: claimer, amount: depositAmount });
        boost.claimTokens(claim, _generateClaimSignature(claim));
        vm.prank(owner);
        vm.expectRevert(IBoost.InsufficientBoostBalance.selector);
        boost.withdrawRemainingTokens(boostId, owner);
    }
}

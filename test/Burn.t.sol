// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./Boost.t.sol";

contract BoostWithdrawTest is BoostTest {
    address public constant claimer = address(0x1111);
    address public constant claimer2 = address(0x2222);
    address public constant claimer3 = address(0x3333);

    function testWithdrawAfterBoostExpired() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostId = _createBoost();

        assertEq(boost.balanceOf(owner), 1); // sanity check
        // Increasing timestamp to after boost has ended
        vm.warp(block.timestamp + 60);
        vm.prank(owner);
        snapStart("Withdraw");
        boost.burn(boostId, owner);
        snapEnd();

        // Checking balances after withdrawal
        assertEq(token.balanceOf(address(boost)), 0);
        assertEq(token.balanceOf(owner), depositAmount);
        assertEq(boost.balanceOf(owner), 0);
    }

    function testWithdrawBoostNotOwner() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostId = _createBoost();

        vm.warp(block.timestamp + 60);
        // Not boost owner
        vm.prank(claimer);
        vm.expectRevert(IBoost.OnlyBoostOwner.selector);
        boost.burn(boostId, claimer);
    }

    function testWithdrawBoostNotExpired() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostId = _createBoost();

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(IBoost.BoostNotEnded.selector, block.timestamp + 60));
        // Boost still active
        boost.burn(boostId, owner);
    }

    function testWithdrawZeroBalance() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostId = _createBoost();

        // Claiming the entire deposit amount so that the boost balance will be zero
        IBoost.ClaimConfig memory claim = IBoost.ClaimConfig({
            boostId: boostId,
            recipient: claimer,
            amount: depositAmount,
            ref: keccak256("1")
        });
        boost.claim(claim, _generateClaimSignature(claim));
        vm.warp(block.timestamp + 60);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "./Boost.t.sol";

contract BoostDepositTest is BoostTest {
    function testDepositToExistingBoost() public {
        _mintAndApprove(owner, depositAmount * 2, depositAmount * 2);
        uint256 boostID = _createBoost();
        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit TokensDeposited(boostID, owner, depositAmount);
        boost.depositTokens(boostID, depositAmount);
    }

    function testDepositFromDifferentAccount() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        _mintAndApprove(guard, 50, 50);
        vm.prank(owner);
        uint256 boostID = _createBoost();
        vm.prank(guard);
        boost.depositTokens(boostID, 50);
    }

    function testDepositToBoostThatDoesntExist() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        vm.prank(owner);
        vm.expectRevert(IBoost.BoostDoesNotExist.selector);
        boost.depositTokens(1, depositAmount);
    }

    function testDepositToExpiredBoost() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostID = _createBoost();
        vm.warp(block.timestamp + 60);
        vm.prank(owner);
        vm.expectRevert(IBoost.BoostEnded.selector);
        boost.depositTokens(boostID, depositAmount);
    }

    function testDepositExceedsAllowance() public {
        _mintAndApprove(owner, depositAmount * 2, depositAmount);
        uint256 boostID = _createBoost();
        vm.prank(owner);
        vm.expectRevert("ERC20: insufficient allowance");
        boost.depositTokens(boostID, 10);
    }

    function testDepositExceedsBalance() public {
        _mintAndApprove(owner, depositAmount, 200);
        uint256 boostID = _createBoost();
        vm.prank(owner);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        boost.depositTokens(boostID, 10);
    }

    function testDepositZero() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostID = _createBoost();
        vm.prank(owner);
        vm.expectRevert(IBoost.BoostDepositRequired.selector);
        boost.depositTokens(boostID, 0);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "./Boost.t.sol";

contract BoostDepositTest is BoostTest {
    function testDepositToExistingBoost() public {
        _mintAndApprove(owner, 200, 200);
        uint256 boostID = _createBoost(100);
        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit TokensDeposited(boostID, owner, 100);
        snapStart("Deposit");
        boost.depositTokens(boostID, 100);
        snapEnd();
    }

    function testDepositFromDifferentAccount() public {
        _mintAndApprove(owner, 200, 200);
        _mintAndApprove(guard, 50, 50);
        vm.prank(owner);
        uint256 boostID = _createBoost(100);
        vm.prank(guard);
        boost.depositTokens(boostID, 50);
    }

    function testDepositToBoostThatDoesntExist() public {
        _mintAndApprove(owner, 200, 200);
        vm.prank(owner);
        vm.expectRevert(IBoost.BoostDoesNotExist.selector);
        boost.depositTokens(1, 100);
    }

    function testDepositToExpiredBoost() public {
        _mintAndApprove(owner, 200, 200);
        uint256 boostID = _createBoost(100);
        vm.warp(block.timestamp + 60);
        vm.prank(owner);
        vm.expectRevert(IBoost.BoostEnded.selector);
        boost.depositTokens(boostID, 100);
    }

    function testDepositExceedsAllowance() public {
        _mintAndApprove(owner, 200, 50);
        uint256 boostID = _createBoost(50);
        vm.prank(owner);
        vm.expectRevert("ERC20: insufficient allowance");
        boost.depositTokens(boostID, 10);
    }

    function testDepositExceedsBalance() public {
        _mintAndApprove(owner, 100, 200);
        uint256 boostID = _createBoost(100);
        vm.prank(owner);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        boost.depositTokens(boostID, 10);
    }

    function testDepositZero() public {
        _mintAndApprove(owner, 100, 100);
        uint256 boostID = _createBoost(100);
        vm.prank(owner);
        vm.expectRevert(IBoost.BoostDepositRequired.selector);
        boost.depositTokens(boostID, 0);
    }
}

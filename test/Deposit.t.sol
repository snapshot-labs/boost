// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./Boost.t.sol";

contract BoostDepositTest is BoostTest {
    address public constant depositee = address(0x1111);

    // function testDepositToExistingBoost() public {
    //     _mintAndApprove(owner, depositAmount * 2, depositAmount * 2);
    //     uint256 boostID = _createBoost();

    //     vm.prank(owner);
    //     vm.expectEmit(true, true, false, true);
    //     emit TokensDeposited(boostID, owner, 100);
    //     snapStart("Deposit");
    //     boost.depositTokens(boostID, depositAmount);
    //     snapEnd();
    // }

    // function testDepositFromDifferentAccount() public {
    //     _mintAndApprove(owner, depositAmount, depositAmount);
    //     _mintAndApprove(depositee, 50, 50);

    //     vm.prank(owner);
    //     uint256 boostID = _createBoost();

    //     // Depositing from a different account
    //     vm.prank(depositee);
    //     boost.depositTokens(boostID, 50);
    // }

    // function testDepositToBoostThatDoesntExist() public {
    //     _mintAndApprove(owner, depositAmount, depositAmount);

    //     vm.prank(owner);
    //     vm.expectRevert(IBoost.BoostDoesNotExist.selector);
    //     // Boost with id 1 has not been created yet
    //     boost.depositTokens(1, depositAmount);
    // }

    // function testDepositToExpiredBoost() public {
    //     _mintAndApprove(owner, depositAmount, depositAmount);
    //     uint256 boostID = _createBoost();

    //     // Increasing timestamp to after boost has ended
    //     vm.warp(block.timestamp + 60);
    //     vm.prank(owner);
    //     vm.expectRevert(IBoost.BoostEnded.selector);
    //     boost.depositTokens(boostID, depositAmount);
    // }

    // function testDepositExceedsAllowance() public {
    //     _mintAndApprove(owner, depositAmount * 2, depositAmount);
    //     uint256 boostID = _createBoost();

    //     vm.prank(owner);
    //     vm.expectRevert("ERC20: insufficient allowance");
    //     // Full allowance of depositAmount has been used to create the boost
    //     boost.depositTokens(boostID, 1);
    // }

    // function testDepositExceedsBalance() public {
    //     _mintAndApprove(owner, depositAmount, 200);
    //     uint256 boostID = _createBoost();

    //     vm.prank(owner);
    //     vm.expectRevert("ERC20: transfer amount exceeds balance");
    //     // Attempting to deposit more than the owner's balance
    //     boost.depositTokens(boostID, 1);
    // }

    // function testDepositZero() public {
    //     _mintAndApprove(owner, depositAmount, depositAmount);
    //     uint256 boostID = _createBoost();
    //     vm.prank(owner);
    //     vm.expectRevert(IBoost.BoostDepositRequired.selector);
    //     boost.depositTokens(boostID, 0);
    // }
}

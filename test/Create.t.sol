// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "./Boost.t.sol";

contract BoostCreateTest is BoostTest {
    function testCreateBoost() public {
        token.mint(owner, depositAmount);
        vm.prank(owner);
        token.approve(address(boost), depositAmount);
        IBoost.BoostConfig memory boostConfig = IBoost.BoostConfig({
            strategyURI: strategyURI,
            token: address(token),
            balance: depositAmount,
            guard: guard,
            start: block.timestamp,
            end: block.timestamp + 60,
            owner: owner
        });
        vm.expectEmit(true, true, false, true);
        emit BoostCreated(1, boostConfig);
        vm.prank(owner);
        boost.createBoost(boostConfig);
        (
            string memory _strategyURI,
            address _token,
            uint256 _balance,
            address _guard,
            uint256 _start,
            uint256 _end,
            address _owner
        ) = boost.boosts(1);
        assertEq(boostConfig.strategyURI, _strategyURI);
        assertEq(boostConfig.token, _token);
        assertEq(boostConfig.balance, _balance);
        assertEq(boostConfig.guard, _guard);
        assertEq(boostConfig.start, _start);
        assertEq(boostConfig.end, _end);
        assertEq(boostConfig.owner, _owner);
    }

    function testCreateBoostInsufficientAllowance() public {
        token.mint(owner, depositAmount);
        vm.prank(owner);
        token.approve(address(boost), depositAmount - 1);
        IBoost.BoostConfig memory boostConfig = IBoost.BoostConfig({
            strategyURI: strategyURI,
            token: address(token),
            balance: depositAmount,
            guard: guard,
            start: block.timestamp,
            end: block.timestamp + 60,
            owner: owner
        });
        vm.expectRevert("ERC20: insufficient allowance");
        vm.prank(owner);
        boost.createBoost(boostConfig);
    }

    function testCreateBoostInsufficientBalance() public {
        token.mint(owner, depositAmount - 1);
        vm.prank(owner);
        token.approve(address(boost), depositAmount);
        IBoost.BoostConfig memory boostConfig = IBoost.BoostConfig({
            strategyURI: strategyURI,
            token: address(token),
            balance: depositAmount,
            guard: guard,
            start: block.timestamp,
            end: block.timestamp + 60,
            owner: owner
        });
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        vm.prank(owner);
        boost.createBoost(boostConfig);
    }

    function testCreateBoostZeroDeposit() public {
        IBoost.BoostConfig memory boostConfig = IBoost.BoostConfig({
            strategyURI: strategyURI,
            token: address(token),
            balance: 0,
            guard: guard,
            start: block.timestamp,
            end: block.timestamp + 60,
            owner: owner
        });
        vm.prank(owner);
        vm.expectRevert(IBoost.BoostDepositRequired.selector);
        boost.createBoost(boostConfig);
    }

    function testCreateBoostEndNotGreaterThanStart() public {
        token.mint(owner, depositAmount);
        vm.prank(owner);
        token.approve(address(boost), depositAmount);
        IBoost.BoostConfig memory boostConfig = IBoost.BoostConfig({
            strategyURI: strategyURI,
            token: address(token),
            balance: depositAmount,
            guard: guard,
            start: block.timestamp,
            end: block.timestamp,
            owner: owner
        });
        vm.prank(owner);
        vm.expectRevert(IBoost.BoostEndDateInPast.selector);
        boost.createBoost(boostConfig);
    }

    // function testDepositToExistingBoost() public {
    //     _mintAndApprove(owner, 200, 200);
    //     uint256 boostID = _createBoost(100);
    //     vm.prank(owner);
    //     vm.expectEmit(true, true, false, true);
    //     emit TokensDeposited(boostID, owner, 100);
    //     boost.depositTokens(boostID, 100);
    // }

    // function testDepositFromDifferentAccount() public {
    //     _mintAndApprove(owner, 200, 200);
    //     _mintAndApprove(guard, 50, 50);
    //     vm.prank(owner);
    //     uint256 boostID = _createBoost(100);
    //     vm.prank(guard);
    //     boost.depositTokens(boostID, 50);
    // }

    // function testDepositToBoostThatDoesntExist() public {
    //     _mintAndApprove(owner, 200, 200);
    //     vm.prank(owner);
    //     vm.expectRevert(IBoost.BoostDoesNotExist.selector);
    //     boost.depositTokens(1, 100);
    // }

    // function testDepositToExpiredBoost() public {
    //     _mintAndApprove(owner, 200, 200);
    //     uint256 boostID = _createBoost(100);
    //     vm.warp(block.timestamp + 60);
    //     vm.prank(owner);
    //     vm.expectRevert(IBoost.BoostEnded.selector);
    //     boost.depositTokens(boostID, 100);
    // }

    // function testDepositExceedsAllowance() public {
    //     _mintAndApprove(owner, 200, 50);
    //     uint256 boostID = _createBoost(50);
    //     vm.prank(owner);
    //     vm.expectRevert("ERC20: insufficient allowance");
    //     boost.depositTokens(boostID, 10);
    // }

    // function testDepositExceedsBalance() public {
    //     _mintAndApprove(owner, 100, 200);
    //     uint256 boostID = _createBoost(100);
    //     vm.prank(owner);
    //     vm.expectRevert("ERC20: transfer amount exceeds balance");
    //     boost.depositTokens(boostID, 10);
    // }

    // function testDepositZero() public {
    //     _mintAndApprove(owner, 100, 100);
    //     uint256 boostID = _createBoost(100);
    //     vm.prank(owner);
    //     vm.expectRevert(IBoost.BoostDepositRequired.selector);
    //     boost.depositTokens(boostID, 0);
    // }
}
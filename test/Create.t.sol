// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./Boost.t.sol";

contract BoostCreateTest is BoostTest {
    function testCreateBoost() public {
        token.mint(owner, depositAmount);
        vm.prank(owner);
        token.approve(address(boost), depositAmount);
        // Id of the next boost that will be created
        uint256 boostId = boost.nextBoostId();
        vm.expectEmit(true, true, false, true);
        emit BoostCreated(
            1,
            IBoost.BoostConfig({
                token: IERC20(address(token)),
                balance: depositAmount,
                guard: guard,
                start: block.timestamp,
                end: block.timestamp + 60
            })
        );
        vm.prank(owner);
        snapStart("CreateBoost");
        boost.createBoost(
            strategyURI,
            IERC20(address(token)),
            depositAmount,
            guard,
            block.timestamp,
            block.timestamp + 60,
            owner
        );
        snapEnd();

        // Checking BoostConfig object and other data that we store separately to obey the ERC721 standard
        (IERC20 _token, uint256 _balance, address _guard, uint256 _start, uint256 _end) = boost.boosts(boostId);
        assertEq(address(token), address(_token));
        assertEq(depositAmount, _balance);
        assertEq(guard, _guard);
        assertEq(block.timestamp, _start);
        assertEq(block.timestamp + 60, _end);
        assertEq(boost.ownerOf(boostId), owner);
        assertEq(boost.tokenURI(boostId), string(abi.encodePacked("ipfs://", strategyURI)));

        // Checking boost balance is equal to the deposit amount
        assertEq(token.balanceOf(address(boost)), depositAmount);
    }

    function testCreateBoostInsufficientAllowance() public {
        token.mint(owner, depositAmount);
        vm.prank(owner);
        token.approve(address(boost), depositAmount - 1);
        vm.expectRevert("ERC20: insufficient allowance");
        vm.prank(owner);
        // Attempting to deposit more than what the contract is approved for
        boost.createBoost(
            strategyURI,
            IERC20(address(token)),
            depositAmount,
            guard,
            block.timestamp,
            block.timestamp + 60,
            owner
        );
    }

    function testCreateBoostInsufficientBalance() public {
        token.mint(owner, depositAmount - 1);
        vm.prank(owner);
        token.approve(address(boost), depositAmount);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        vm.prank(owner);
        // Attempting to deposit more than the owner's balance
        boost.createBoost(
            strategyURI,
            IERC20(address(token)),
            depositAmount,
            guard,
            block.timestamp,
            block.timestamp + 60,
            owner
        );
    }

    function testCreateBoostZeroDeposit() public {
        vm.prank(owner);
        vm.expectRevert(IBoost.BoostDepositRequired.selector);
        // Deposit of zero
        boost.createBoost(strategyURI, IERC20(address(token)), 0, guard, block.timestamp, block.timestamp + 60, owner);
    }

    function testCreateBoostEndNotGreaterThanStart() public {
        token.mint(owner, depositAmount);
        vm.prank(owner);
        token.approve(address(boost), depositAmount);
        vm.prank(owner);
        vm.expectRevert(IBoost.BoostEndDateInPast.selector);
        // Start and end timestamps are equal
        boost.createBoost(
            strategyURI,
            IERC20(address(token)),
            depositAmount,
            guard,
            block.timestamp,
            block.timestamp,
            owner
        );
    }
}

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
        assertEq(boostId, 0); // The first boost created should have an id of 0
        vm.expectEmit(true, true, false, true);
        emit Mint(
            boostId,
            IBoost.BoostConfig({
                token: IERC20(address(token)),
                balance: depositAmount,
                guard: guard,
                start: uint48(block.timestamp),
                end: uint48(block.timestamp + 60)
            })
        );
        vm.prank(owner);

        boost.mint(
            strategyURI,
            IERC20(address(token)),
            depositAmount,
            owner,
            guard,
            uint48(block.timestamp),
            uint48(block.timestamp + 60)
        );

        // Checking BoostConfig object and other data that we store separately to obey the ERC721 standard
        (IERC20 _token, uint256 _balance, address _guard, uint48 _start, uint48 _end) = boost.boosts(boostId);
        assertEq(address(token), address(_token));
        assertEq(depositAmount, _balance);
        assertEq(guard, _guard);
        assertEq(uint48(block.timestamp), _start);
        assertEq(uint48(block.timestamp + 60), _end);
        assertEq(boost.ownerOf(boostId), owner);
        assertEq(boost.tokenURI(boostId), strategyURI);
        assertEq(boost.balanceOf(owner), 1); // The owner minted a single boost

        // Checking boost balance is equal to the deposit amount
        assertEq(token.balanceOf(address(boost)), depositAmount);
    }

    function testCreateMultipleBoosts() public {
        _mintAndApprove(owner, 2 * depositAmount, 2 * depositAmount);

        // Creating 2 boosts, gas snapshot on second
        uint256 boostId1 = _createBoost();
        snapStart("CreateBoost");
        uint256 boostId2 = _createBoost();
        snapEnd();

        assertEq(boostId1, 0);
        assertEq(boostId2, 1);

        // After creating 2 boosts, the owner's balance should be 2
        assertEq(boost.balanceOf(owner), 2);
        assertEq(token.balanceOf(address(boost)), 2 * depositAmount);
    }

    function testCreateBoostInsufficientAllowance() public {
        token.mint(owner, depositAmount);
        vm.prank(owner);
        token.approve(address(boost), depositAmount - 1);
        vm.expectRevert("ERC20: insufficient allowance");
        vm.prank(owner);
        // Attempting to deposit more than what the contract is approved for
        boost.mint(
            strategyURI,
            IERC20(address(token)),
            depositAmount,
            owner,
            guard,
            uint48(block.timestamp),
            uint48(block.timestamp + 60)
        );
    }

    function testCreateBoostInsufficientBalance() public {
        token.mint(owner, depositAmount - 1);
        vm.prank(owner);
        token.approve(address(boost), depositAmount);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        vm.prank(owner);
        // Attempting to deposit more than the owner's balance
        boost.mint(
            strategyURI,
            IERC20(address(token)),
            depositAmount,
            owner,
            guard,
            uint48(block.timestamp),
            uint48(block.timestamp + 60)
        );
    }

    function testCreateBoostZeroDeposit() public {
        vm.prank(owner);
        vm.expectRevert(IBoost.BoostDepositRequired.selector);
        // Deposit of zero
        boost.mint(
            strategyURI,
            IERC20(address(token)),
            0,
            owner,
            guard,
            uint48(block.timestamp),
            uint48(block.timestamp + 60)
        );
    }

    function testCreateBoostEndNotGreaterThanStart() public {
        token.mint(owner, depositAmount);
        vm.prank(owner);
        token.approve(address(boost), depositAmount);
        vm.prank(owner);
        vm.expectRevert(IBoost.BoostEndDateInPast.selector);
        // Start and end timestamps are equal
        boost.mint(
            strategyURI,
            IERC20(address(token)),
            depositAmount,
            owner,
            guard,
            uint48(block.timestamp),
            uint48(block.timestamp)
        );
    }
}

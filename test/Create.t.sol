// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./Boost.t.sol";

contract BoostCreateTest is BoostTest {
    function testCreateBoost() public {
        token.mint(owner, depositAmount);
        vm.prank(owner);
        token.approve(address(boost), depositAmount);
        vm.expectEmit(true, true, false, true);
        emit BoostCreated(
            1,
            strategyURI,
            IBoost.BoostConfig({
                strategyURI: strategyURI,
                token: IERC20(address(token)),
                balance: depositAmount,
                owner: owner,
                guard: guard,
                start: uint48(block.timestamp),
                end: uint48(block.timestamp + 60)
            })
        );
        vm.prank(owner);
        snapStart("CreateBoost");
        boost.createBoost(
            strategyURI,
            IERC20(address(token)),
            depositAmount,
            owner,
            guard,
            uint48(block.timestamp),
            uint48(block.timestamp + 60)
        );
        snapEnd();

        // Checking contents of BoostConfig object
        (
            string memory _strategyURI,
            IERC20 _token,
            uint256 _balance,
            address _owner,
            address _guard,
            uint48 _start,
            uint48 _end
        ) = boost.boosts(1);
        assertEq(strategyURI, _strategyURI);
        assertEq(address(token), address(_token));
        assertEq(depositAmount, _balance);
        assertEq(guard, _guard);
        assertEq(block.timestamp, _start);
        assertEq(block.timestamp + 60, _end);
        assertEq(owner, _owner);

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
        boost.createBoost(
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
        boost.createBoost(
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
        boost.createBoost(
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

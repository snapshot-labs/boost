// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "./Boost.t.sol";
import "forge-std/console2.sol";

contract ProtocolFeesTest is BoostTest {
    uint256 ethFee = 1000;
    uint256 tokenFee = 10;

    function setUp() public override {
        token = new MockERC20("Test Token", "TEST");
        boost = new Boost(protocolOwner, ethFee, tokenFee);
    }

    function testCreateBoostWithProtocolFees() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 tokenFeeAmount = depositAmount / tokenFee;
        uint256 boostBalance = depositAmount - tokenFeeAmount;
        vm.expectEmit(true, true, false, true);
        emit BoostCreated(
            1,
            IBoost.BoostConfig({
                strategyURI: strategyURI,
                token: IERC20(address(token)),
                balance: boostBalance,
                guard: guard,
                start: block.timestamp,
                end: block.timestamp + 60,
                owner: owner
            })
        );
        vm.deal(owner, ethFee);
        vm.prank(owner);
        boost.createBoost{ value: ethFee }(
            strategyURI,
            IERC20(address(token)),
            depositAmount,
            guard,
            block.timestamp,
            block.timestamp + 60,
            owner
        );
        (
            string memory _strategyURI,
            IERC20 _token,
            uint256 _balance,
            address _guard,
            uint256 _start,
            uint256 _end,
            address _owner
        ) = boost.boosts(1);
        assertEq(strategyURI, _strategyURI);
        assertEq(address(token), address(_token));
        assertEq(boostBalance, _balance);
        assertEq(guard, _guard);
        assertEq(block.timestamp, _start);
        assertEq(block.timestamp + 60, _end);
        assertEq(owner, _owner);

        assertEq(address(boost).balance, ethFee);
        assertEq(owner.balance, 0);
        assertEq(token.balanceOf(address(boost)), boostBalance);
        assertEq(token.balanceOf(protocolOwner), tokenFeeAmount);
    }

    function testUpdateProtocolFees() public {
        uint256 newEthFee = 2000;
        uint256 newTokenFee = 20;
        vm.prank(protocolOwner);
        boost.updateProtocolFees(newEthFee, newTokenFee);
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 tokenFeeAmount = depositAmount / newTokenFee;
        uint256 boostBalance = depositAmount - tokenFeeAmount;
        uint256 boostId = _createBoost(
            strategyURI,
            address(token),
            depositAmount,
            guard,
            block.timestamp,
            block.timestamp + 60,
            owner,
            newEthFee
        );
        assertEq(address(boost).balance, newEthFee);
        assertEq(owner.balance, 0);
        assertEq(token.balanceOf(address(boost)), boostBalance);
        assertEq(token.balanceOf(protocolOwner), tokenFeeAmount);
    }

    function testDepositWithProtocolFees() public {
        _mintAndApprove(owner, depositAmount * 2, depositAmount * 2);
        uint256 boostId = _createBoost(
            strategyURI,
            address(token),
            depositAmount,
            guard,
            block.timestamp,
            block.timestamp + 60,
            owner,
            ethFee
        );
        uint256 tokenFeeAmount = depositAmount / tokenFee;
        uint256 boostBalanceIncrease = depositAmount - tokenFeeAmount;
        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit TokensDeposited(boostId, owner, boostBalanceIncrease);
        boost.depositTokens(boostId, depositAmount);

        assertEq(address(boost).balance, ethFee);
        assertEq(owner.balance, 0);
        // The deposit amount when the boost was created and when a deposit was added was the same therefore
        // we multiply the balance increase and token fee amount by 2 to get the aggregate values.
        assertEq(token.balanceOf(address(boost)), 2 * boostBalanceIncrease);
        assertEq(token.balanceOf(protocolOwner), 2 * tokenFeeAmount);
    }

    function testCollectEthFees() public {
        _mintAndApprove(owner, depositAmount * 2, depositAmount * 2);
        uint256 boostId = _createBoost(
            strategyURI,
            address(token),
            depositAmount,
            guard,
            block.timestamp,
            block.timestamp + 60,
            owner,
            ethFee
        );
        vm.prank(protocolOwner);
        boost.collectEthFees();
        assertEq(address(boost).balance, 0);
        assertEq(protocolOwner.balance, ethFee);
    }

    function testInsufficientEthFee() public {
        _mintAndApprove(owner, depositAmount * 2, depositAmount * 2);
        vm.expectRevert(IBoost.InsufficientEthFee.selector);
        vm.prank(owner);
        vm.deal(owner, ethFee - 1);
        boost.createBoost{ value: ethFee - 1 }(
            strategyURI,
            IERC20(token),
            depositAmount,
            guard,
            block.timestamp,
            block.timestamp + 60,
            owner
        );
    }

    function test100PercentTokenFee() public {
        uint256 newEthFee = 0;
        uint256 newTokenFee = 1;
        vm.prank(protocolOwner);
        boost.updateProtocolFees(newEthFee, newTokenFee);
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostId = _createBoost();
        assertEq(owner.balance, 0);
        // 100% protocol fee, boost balance is zero
        assertEq(token.balanceOf(address(boost)), 0);
        assertEq(token.balanceOf(protocolOwner), depositAmount);
    }

    function testMinTokenFee() public {
        uint256 newEthFee = 0;
        uint256 newTokenFee = type(uint256).max;
        vm.prank(protocolOwner);
        boost.updateProtocolFees(newEthFee, newTokenFee);
        _mintAndApprove(owner, depositAmount, depositAmount);
        // Division is rounded towards zero and depositAmount < newTokenFee, therefore the tokenFeeAmount will be zero
        uint256 tokenFeeAmount = depositAmount / newTokenFee;
        uint256 boostBalance = depositAmount - tokenFeeAmount;
        uint256 boostId = _createBoost();
        assertEq(owner.balance, 0);
        assertEq(token.balanceOf(address(boost)), depositAmount);
        assertEq(token.balanceOf(protocolOwner), 0);
    }
}

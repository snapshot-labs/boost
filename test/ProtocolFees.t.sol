// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "./Boost.t.sol";

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
            strategyURI,
            IBoost.BoostConfig({
                strategyURI: strategyURI,
                token: IERC20(address(token)),
                balance: boostBalance,
                owner: owner,
                guard: guard,
                start: uint48(block.timestamp),
                end: uint48(block.timestamp + 60)
            })
        );

        vm.deal(owner, ethFee);
        vm.prank(owner);
        snapStart("CreateBoostWithProtocolFee");
        boost.createBoost{ value: ethFee }(
            strategyURI,
            IERC20(address(token)),
            depositAmount,
            owner,
            guard,
            uint48(block.timestamp),
            uint48(block.timestamp + 60)
        );
        snapEnd();

        // Checking BoostConfig object is correct
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
        assertEq(boostBalance, _balance);
        assertEq(guard, _guard);
        assertEq(uint48(block.timestamp), _start);
        assertEq(uint48(block.timestamp + 60), _end);
        assertEq(owner, _owner);

        // Checking balances of eth and the token are correct
        assertEq(address(boost).balance, ethFee);
        assertEq(owner.balance, 0);
        assertEq(token.balanceOf(address(boost)), depositAmount);
        assertEq(boost.tokenFeeBalances(address(token)), tokenFeeAmount);
    }

    function testUpdateProtocolFees() public {
        uint256 newEthFee = 2000;
        uint256 newTokenFee = 20;

        vm.expectEmit(true, true, false, true);
        emit EthFeeSet(newEthFee);
        vm.prank(protocolOwner);
        boost.setEthFee(newEthFee);

        vm.expectEmit(true, true, false, true);
        emit TokenFeeSet(newTokenFee);
        vm.prank(protocolOwner);
        boost.setTokenFee(newTokenFee);

        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 tokenFeeAmount = depositAmount / newTokenFee;
        _createBoost(
            strategyURI,
            address(token),
            depositAmount,
            owner,
            guard,
            block.timestamp,
            block.timestamp + 60,
            newEthFee
        );

        // Checking balances of eth and the token are correct
        assertEq(address(boost).balance, newEthFee);
        assertEq(owner.balance, 0);
        assertEq(token.balanceOf(address(boost)), depositAmount);
        assertEq(boost.tokenFeeBalances(address(token)), tokenFeeAmount);
    }

    function testSetEthFeeNotProtocolOwner() public {
        uint256 newEthFee = 2000;
        vm.expectRevert("Ownable: caller is not the owner");
        boost.setEthFee(newEthFee);
    }

    function testSetTokenFeeNotProtocolOwner() public {
        uint256 newTokenFee = 20;
        vm.expectRevert("Ownable: caller is not the owner");
        boost.setTokenFee(newTokenFee);
    }

    function testDepositWithProtocolFees() public {
        _mintAndApprove(owner, depositAmount * 2, depositAmount * 2);
        uint256 boostId = _createBoost(
            strategyURI,
            address(token),
            depositAmount,
            owner,
            guard,
            block.timestamp,
            block.timestamp + 60,
            ethFee
        );

        uint256 tokenFeeAmount = depositAmount / tokenFee;
        uint256 boostBalanceIncrease = depositAmount - tokenFeeAmount;

        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit TokensDeposited(boostId, owner, boostBalanceIncrease);
        snapStart("DepositWithProtocolFees");
        boost.depositTokens(boostId, depositAmount);
        snapEnd();
        assertEq(address(boost).balance, ethFee);
        assertEq(owner.balance, 0);
        // The deposit amount when the boost was created and when a deposit was added was the same therefore
        // we multiply the balance increase and token fee amount by 2 to get the aggregate values.
        assertEq(token.balanceOf(address(boost)), 2 * depositAmount);
        assertEq(boost.tokenFeeBalances(address(token)), 2 * tokenFeeAmount);
    }

    function testCollectFees() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 tokenFeeAmount = depositAmount / tokenFee;
        _createBoost(
            strategyURI,
            address(token),
            depositAmount,
            owner,
            guard,
            block.timestamp,
            block.timestamp + 60,
            ethFee
        );

        assertEq(address(boost).balance, ethFee);
        assertEq(protocolOwner.balance, 0);
        assertEq(token.balanceOf(address(boost)), depositAmount);
        assertEq(boost.tokenFeeBalances(address(token)), tokenFeeAmount);

        vm.prank(protocolOwner);
        vm.expectEmit(true, true, false, true);
        emit EthFeesCollected(protocolOwner);
        boost.collectEthFees(protocolOwner);

        vm.prank(protocolOwner);
        vm.expectEmit(true, true, false, true);
        emit TokenFeesCollected(IERC20(token), protocolOwner);
        boost.collectTokenFees(IERC20(token), protocolOwner);

        // Checking balances are correct after fees are collected
        assertEq(address(boost).balance, 0);
        assertEq(protocolOwner.balance, ethFee);
        assertEq(token.balanceOf(address(boost)), depositAmount - tokenFeeAmount);
        assertEq(boost.tokenFeeBalances(address(token)), 0);
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
            owner,
            guard,
            uint48(block.timestamp),
            uint48(block.timestamp + 60)
        );
    }

    function test100PercentTokenFee() public {
        uint256 newEthFee = 0;
        uint256 newTokenFee = 1;

        vm.prank(protocolOwner);
        boost.setEthFee(newEthFee);
        vm.prank(protocolOwner);
        boost.setTokenFee(newTokenFee);

        _mintAndApprove(owner, depositAmount, depositAmount);
        _createBoost();

        (, , uint256 _balance, , , , ) = boost.boosts(1);

        // 100% protocol fee, boost balance is zero, token fee is the full deposit
        assertEq(_balance, 0);
        assertEq(token.balanceOf(address(boost)), depositAmount);
        assertEq(boost.tokenFeeBalances(address(token)), depositAmount);
    }

    function testMinTokenFee() public {
        uint256 newEthFee = 0;
        uint256 newTokenFee = type(uint256).max;

        vm.prank(protocolOwner);
        boost.setEthFee(newEthFee);
        vm.prank(protocolOwner);
        boost.setTokenFee(newTokenFee);
        _mintAndApprove(owner, depositAmount, depositAmount);
        _createBoost();

        assertEq(token.balanceOf(address(boost)), depositAmount);
        // Division is rounded towards zero and depositAmount < newTokenFee, therefore the token fee amount will be zero
        assertEq(token.balanceOf(protocolOwner), 0);
    }

    function testUpdateProtocolOwner() public {
        address newProtocolOwner = address(0xBEEF);
        vm.prank(protocolOwner);
        vm.expectEmit(true, true, false, true);
        emit OwnershipTransferred(protocolOwner, newProtocolOwner);
        boost.transferOwnership(newProtocolOwner);
    }

    function testUpdateProtocolOwnerNotProtocolOwner() public {
        address newProtocolOwner = address(0xBEEF);
        vm.expectRevert("Ownable: caller is not the owner");
        boost.transferOwnership(newProtocolOwner);
    }

    function testProtocolOwnerRenounceOwnership() public {
        vm.prank(protocolOwner);
        vm.expectEmit(true, true, false, true);
        emit OwnershipTransferred(protocolOwner, address(0));
        boost.renounceOwnership();
    }
}

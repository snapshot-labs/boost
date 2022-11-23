// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "./Boost.t.sol";

contract ProtocolFeesTest is BoostTest {
    function setUp() public override {
        token = new MockERC20("Test Token", "TEST");
    }

    function testCreateBoostWithProtocolFees() public {
        boost = new Boost(protocolOwner, 0, 10);

        token.mint(owner, depositAmount);
        vm.prank(owner);
        token.approve(address(boost), depositAmount);
        uint256 tokenFee = depositAmount / 10;
        uint256 boostBalance = depositAmount - tokenFee;
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
        vm.prank(owner);
        boost.createBoost(
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

        assertEq(token.balanceOf(address(boost)), boostBalance);
        assertEq(token.balanceOf(protocolOwner), tokenFee);
    }

    // function testUpdateProtocolFees() public {

    // }

    // function testCollectEthFees() public {

    // }

    // function testOverFlowEthFees() public {

    // }
}

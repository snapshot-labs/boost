// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/Boost.sol";
import "./mocks/MockERC20.sol";
import "../src/IBoost.sol";

contract BoostTest is Test {
    event BoostCreated(uint256 boostId, IBoost.BoostConfig boost);
    event TokensClaimed(IBoost.Claim claim);
    event TokensDeposited(uint256 boostId, address sender, uint256 amount);
    event RemainingTokensWithdrawn(uint256 boostId, uint256 amount);

    error BoostDoesNotExist();
    error BoostDepositRequired();
    error BoostEndDateInPast();
    error BoostEndDateBeforeStart();
    error BoostEnded();
    error BoostNotEnded(uint256 end);
    error BoostNotStarted(uint256 start);
    error OnlyBoostOwner();
    error InvalidRecipient();
    error InvalidGuard();
    error RecipientAlreadyClaimed();
    error InvalidSignature();
    error InsufficientBoostBalance();

    Boost public boost;
    MockERC20 public token;

    address public constant owner = address(0x1234);
    address public constant guard = address(0x5678);

    uint256 public constant depositAmount = 100;
    string public constant strategyURI = "abc123";

    function setUp() public {
        boost = new Boost();
        token = new MockERC20("Test Token", "TEST");
    }

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
}

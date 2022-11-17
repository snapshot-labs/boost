// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/Boost.sol";
import "./mocks/MockERC20.sol";
import "../src/IBoost.sol";

import "openzeppelin-contracts/utils/cryptography/SignatureChecker.sol";

abstract contract BoostTest is Test, EIP712("boost", "1") {

    bytes32 public immutable eip712ClaimStructHash =
        keccak256("Claim(uint256 boostId,address recipient,uint256 amount)");

    bytes32 public constant domainSeparator = 0xd8d1c3bc2cb8b823d8b8651dd669ba23441e7e1ee9e0b53fe5ed602c863d5189;

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

    uint256 public constant ownerKey = 1234;
    uint256 public constant guardKey = 5678;
    address public owner = vm.addr(ownerKey);
    address public guard = vm.addr(guardKey);

    uint256 public constant depositAmount = 100;
    string public constant strategyURI = "abc123";

    function _createBoost(uint256 amount) internal returns (uint256) {
        IBoost.BoostConfig memory boostConfig = IBoost.BoostConfig({
            strategyURI: strategyURI,
            token: address(token),
            balance: amount,
            guard: guard,
            start: block.timestamp,
            end: block.timestamp + 60,
            owner: owner
        });
        uint256 boostID = boost.nextBoostId();
        vm.prank(owner);
        boost.createBoost(boostConfig);
        return boostID;
    }

    function _mintAndApprove(address user, uint256 mintAmount, uint256 approveAmount) internal {
        token.mint(user, mintAmount);
        vm.prank(user);
        token.approve(address(boost), approveAmount);
    }

    function setUp() public {
        boost = new Boost();
        token = new MockERC20("Test Token", "TEST");
    }

    function _generateClaimSignature(IBoost.Claim memory claim) internal returns (bytes memory) {
        bytes32 digest = ECDSA.toTypedDataHash(domainSeparator, keccak256(abi.encode(eip712ClaimStructHash, claim.boostId, claim.recipient, claim.amount))
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(guardKey, digest);
        return abi.encodePacked(r, s, v);
    }

}

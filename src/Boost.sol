// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/utils/cryptography/SignatureChecker.sol";
import "openzeppelin-contracts/utils/cryptography/draft-EIP712.sol";
import "./IBoost.sol";

import "forge-std/console2.sol";

contract Boost is IBoost, EIP712("boost", "1") {
    bytes32 public constant eip712ClaimStructHash =
        keccak256("Claim(uint256 boostId,address recipient,uint256 amount)");

    uint256 public nextBoostId = 1;
    mapping(uint256 => BoostConfig) public boosts;
    mapping(address => mapping(uint256 => bool)) public claimed;

    struct Claim2 {
        address recipient;
        uint256 amount;
    }

    /// @notice Create a new boost and transfer tokens to it
    function createBoost(BoostConfig calldata boost) external override {
        if (boost.balance == 0) revert BoostDepositRequired();
        if (boost.end <= block.timestamp) revert BoostEndDateInPast();
        if (boost.start >= boost.end) revert BoostEndDateBeforeStart();
        if (boost.guard == address(0)) revert InvalidGuard();

        uint256 newId = nextBoostId;
        nextBoostId++;
        boosts[newId] = boost;

        IERC20 token = IERC20(boost.token);
        token.transferFrom(msg.sender, address(this), boost.balance);

        emit BoostCreated(newId, boosts[newId]);
    }

    /// @notice Top up an existing boost
    function depositTokens(uint256 boostId, uint256 amount) external override {
        if (amount == 0) revert BoostDepositRequired();
        if (boosts[boostId].owner == address(0)) revert BoostDoesNotExist();
        if (boosts[boostId].end <= block.timestamp) revert BoostEnded();

        boosts[boostId].balance += amount;

        IERC20 token = IERC20(boosts[boostId].token);
        token.transferFrom(msg.sender, address(this), amount);

        emit TokensDeposited(boostId, msg.sender, amount);
    }

    /// @notice Withdraw remaining tokens from an expired boost
    function withdrawRemainingTokens(uint256 boostId, address to) external override {
        if (boosts[boostId].balance == 0) revert InsufficientBoostBalance();
        if (boosts[boostId].end > block.timestamp) revert BoostNotEnded(boosts[boostId].end);
        if (boosts[boostId].owner != msg.sender) revert OnlyBoostOwner();
        if (to == address(0)) revert InvalidRecipient();

        uint256 amount = boosts[boostId].balance;
        boosts[boostId].balance = 0;

        IERC20 token = IERC20(boosts[boostId].token);
        token.transfer(to, amount);

        emit RemainingTokensWithdrawn(boostId, amount);
    }

    /// @notice Claim using a guard signature
    function claimTokens(Claim calldata claim, bytes calldata signature) external override {
        if (boosts[claim.boostId].start > block.timestamp) revert BoostNotStarted(boosts[claim.boostId].start);
        if (boosts[claim.boostId].balance < claim.amount) revert InsufficientBoostBalance();
        if (boosts[claim.boostId].end <= block.timestamp) revert BoostEnded();
        if (claimed[claim.recipient][claim.boostId]) revert RecipientAlreadyClaimed();
        if (claim.recipient == address(0)) revert InvalidRecipient();

        bytes32 digest = _hashTypedDataV4(
            keccak256(abi.encode(eip712ClaimStructHash, claim.boostId, claim.recipient, claim.amount))
        );

        if (!SignatureChecker.isValidSignatureNow(boosts[claim.boostId].guard, digest, signature))
            revert InvalidSignature();

        claimed[claim.recipient][claim.boostId] = true;
        boosts[claim.boostId].balance -= claim.amount;

        IERC20 token = IERC20(boosts[claim.boostId].token);
        token.transfer(claim.recipient, claim.amount);

        emit TokensClaimed(claim);
    }

    /// Claim multiple for the same boost
    function claimMultiple(
        uint256 boostId,
        address[] memory recipients,
        uint256[] calldata amounts,
        bytes[] calldata signatures
    ) external {
        uint256 claimedAmount;
        for (uint i = 0; i < signatures.length; i++) {
            if (boosts[boostId].start > block.timestamp) revert BoostNotStarted(boosts[boostId].start);
            if (boosts[boostId].balance < amounts[i]) revert InsufficientBoostBalance();
            if (boosts[boostId].end <= block.timestamp) revert BoostEnded();
            if (claimed[recipients[i]][boostId]) revert RecipientAlreadyClaimed();
            if (recipients[i] == address(0)) revert InvalidRecipient();
            bytes32 digest = _hashTypedDataV4(
                keccak256(abi.encode(eip712ClaimStructHash, boostId, recipients[i], amounts[i]))
            );

            if (!SignatureChecker.isValidSignatureNow(boosts[boostId].guard, digest, signatures[i]))
                revert InvalidSignature();

            claimed[recipients[i]][boostId] = true;

            claimedAmount += amounts[i];

            IERC20 token = IERC20(boosts[boostId].token);
            token.transfer(recipients[i], amounts[i]);
        }

        boosts[boostId].balance -= claimedAmount;
    }

    /// Claim multiple for the same boost
    function claimMultiple2(
        uint256 boostId,
        address[] memory recipients,
        uint256 amount,
        bytes[] calldata signatures
    ) external {
        BoostConfig storage boost = boosts[boostId];
        IERC20 token = IERC20(boost.token);
        if (boost.balance < amount * signatures.length) revert InsufficientBoostBalance();
        if (boost.start > block.timestamp) revert BoostNotStarted(boost.start);
        if (boost.end <= block.timestamp) revert BoostEnded();
        for (uint i = 0; i < signatures.length; i++) {
            if (claimed[recipients[i]][boostId]) revert RecipientAlreadyClaimed();
            bytes32 digest = _hashTypedDataV4(
                keccak256(abi.encode(eip712ClaimStructHash, boostId, recipients[i], amount))
            );
            if (!SignatureChecker.isValidSignatureNow(boost.guard, digest, signatures[i])) revert InvalidSignature();
            claimed[recipients[i]][boostId] = true;
            token.transfer(recipients[i], amount);
        }

        boost.balance -= amount * signatures.length;
        emit MultipleTokensClaimed(boostId, recipients);
    }
}

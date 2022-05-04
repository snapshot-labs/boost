// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

error BoostAlreadyExists();
error BoostDoesNotExist();
error BoostDepositRequired();
error BoostExpireTooLow();
error BoostExpired();
error BoostNotExpired();
error OnlyBoostOwner();
error TooManyRecipients(uint256 allowed);
error RecipientAlreadyClaimed();
error InvalidSignature();
error InsufficientBoostBalance();

contract Boost {
    struct BoostSettings {
        bytes32 id;
        address token;
        uint256 balance;
        uint256 amountPerAccount;
        address guard;
        uint256 expires;
        address owner;
    }

    mapping(bytes32 => BoostSettings) public boosts;
    mapping(address => mapping(bytes32 => bool)) public claimed;

    uint256 public constant MAX_CLAIM_RECIPIENTS = 10;

    // get boost by id
    function getBoost(bytes32 id)
        public
        view
        returns (BoostSettings memory boost)
    {
        boost = boosts[id];
        return boost;
    }

    function create(
        bytes32 id,
        address tokenAddress,
        uint256 depositAmount,
        uint256 amountPerAccount,
        address guard,
        uint256 expires
    ) public {
        if (boosts[id].id != 0x0) revert BoostAlreadyExists();
        if (depositAmount == 0) revert BoostDepositRequired();
        if (expires <= block.timestamp) revert BoostExpireTooLow();

        address boostOwner = msg.sender;

        IERC20 token = IERC20(tokenAddress);
        token.transferFrom(
            boostOwner,
            address(this),
            depositAmount
        );

        boosts[id] = BoostSettings(
            id,
            tokenAddress,
            depositAmount,
            amountPerAccount,
            guard,
            expires,
            boostOwner
        );
    }

    function deposit(bytes32 id, uint256 amount) public {
        if (amount == 0) revert BoostDepositRequired();
        if (boosts[id].id == 0x0) revert BoostDoesNotExist();
        if (boosts[id].owner != msg.sender) revert OnlyBoostOwner();

        IERC20 token = IERC20(boosts[id].token);
        token.transferFrom(
            boosts[id].owner,
            address(this),
            amount
        );

        boosts[id].balance += amount;
    }

    function withdraw(bytes32 id) public {
        if (boosts[id].balance == 0) revert InsufficientBoostBalance();
        if (boosts[id].expires > block.timestamp) revert BoostNotExpired();
        if (boosts[id].owner != msg.sender) revert OnlyBoostOwner();

        uint256 amount = boosts[id].balance;
        boosts[id].balance = 0;

        IERC20 token = IERC20(boosts[id].token);
        token.transfer(boosts[id].owner, amount);
    }

    // claim for multiple accounts
    function claim(
        bytes32 id,
        address[] calldata recipients,
        bytes[] calldata signatures
    ) public {
        if (boosts[id].id == 0x0) revert BoostDoesNotExist();
        if (boosts[id].expires <= block.timestamp) revert BoostExpired();
        if (recipients.length > MAX_CLAIM_RECIPIENTS) revert TooManyRecipients(MAX_CLAIM_RECIPIENTS);

        // check signatures, revert if one is invalid or already claimed
        for (uint256 i = 0; i < recipients.length; i++) {
            if (claimed[recipients[i]][id]) revert RecipientAlreadyClaimed();

            bytes32 messageHash = keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    keccak256(abi.encodePacked(id, recipients[i]))
                )
            );

            if (!SignatureChecker.isValidSignatureNow(
                boosts[id].guard,
                messageHash,
                signatures[i]
            )) revert InvalidSignature();
        }

        // mark as claimed, reduce boost balance and execute transfers
        for (uint256 i = 0; i < recipients.length; i++) {
            if (boosts[id].balance < boosts[id].amountPerAccount)
                revert InsufficientBoostBalance();

            claimed[recipients[i]][id] = true;
            boosts[id].balance -= boosts[id].amountPerAccount;
            IERC20 token = IERC20(boosts[id].token);
            token.transfer(recipients[i], boosts[id].amountPerAccount);
        }
    }
}

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

error BoostAlreadyExists();
error BoostDoesNotExist();
error BoostDepositRequired();
error BoostAmountPerAccountRequired();
error BoostDepositLessThanAmountPerAccount();
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
        bytes32 ref; // external reference, like proposal id
        address token;
        uint256 balance;
        uint256 amountPerAccount;
        address guard;
        uint256 expires; // timestamp, maybe better block number and start/end?
        address owner;
    }

    event BoostCreated(uint256 id);

    uint256 public nextBoostId = 1;
    mapping(uint256 => BoostSettings) public boosts;
    mapping(bytes32 => uint256[]) public boostIdsByRef;
    mapping(address => mapping(uint256 => bool)) public claimed;

    uint256 public constant MAX_CLAIM_RECIPIENTS = 10;

    // get boost by id
    function getBoost(uint256 id)
        public
        view
        returns (BoostSettings memory boost)
    {
        boost = boosts[id];
    }

    // get boosts by ref
    function getBoostIdsByRef(bytes32 ref)
        public
        view
        returns (uint256[] memory ids)
    {
        ids = boostIdsByRef[ref];
    }

    function create(
        bytes32 ref,
        address tokenAddress,
        uint256 depositAmount,
        uint256 amountPerAccount,
        address guard,
        uint256 expires
    ) public {
        if (depositAmount == 0) revert BoostDepositRequired();
        if (amountPerAccount == 0) revert BoostAmountPerAccountRequired();
        if (depositAmount < amountPerAccount) revert BoostDepositLessThanAmountPerAccount();
        if (expires <= block.timestamp) revert BoostExpireTooLow();
        
        address boostOwner = msg.sender;

        boosts[nextBoostId] = BoostSettings(
            ref,
            tokenAddress,
            depositAmount,
            amountPerAccount,
            guard,
            expires,
            boostOwner
        );
        boostIdsByRef[ref].push(nextBoostId);
        emit BoostCreated(nextBoostId);
        nextBoostId++;

        IERC20 token = IERC20(tokenAddress);
        token.transferFrom(
            boostOwner,
            address(this),
            depositAmount
        );
    }

    function deposit(uint256 id, uint256 amount) public {
        if (amount == 0) revert BoostDepositRequired();
        if (boosts[id].owner == address(0)) revert BoostDoesNotExist();
        if (boosts[id].expires <= block.timestamp) revert BoostExpired();
        
        boosts[id].balance += amount;

        IERC20 token = IERC20(boosts[id].token);
        token.transferFrom(
            msg.sender,
            address(this),
            amount
        );
    }

    function withdraw(uint256 id) public {
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
        uint256 id,
        address[] calldata recipients,
        bytes[] calldata signatures
    ) public {
        if (boosts[id].owner == address(0)) revert BoostDoesNotExist();
        if (boosts[id].expires <= block.timestamp) revert BoostExpired();
        if (recipients.length > MAX_CLAIM_RECIPIENTS) revert TooManyRecipients(MAX_CLAIM_RECIPIENTS);

        // check signatures and boost balance, reduce balance and mark as claimed
        for (uint256 i = 0; i < recipients.length; i++) {
            if (boosts[id].balance < boosts[id].amountPerAccount) revert InsufficientBoostBalance();
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

            claimed[recipients[i]][id] = true;
            boosts[id].balance -= boosts[id].amountPerAccount;
        }

        // execute transfers
        for (uint256 i = 0; i < recipients.length; i++) {
            IERC20 token = IERC20(boosts[id].token);
            token.transfer(recipients[i], boosts[id].amountPerAccount);
        }
    }
}

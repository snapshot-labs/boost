// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

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
        require(boosts[id].id == 0x0, "Boost already exists");
        require(depositAmount > 0, "Deposit amount must be > 0");
        require(expires > block.timestamp, "Expire must be > block timestamp");

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
        require(amount > 0, "Amount must be > 0");
        require(boosts[id].id != 0x0, "Boost does not exist");
        require(boosts[id].owner == msg.sender, "Only owner can deposit");

        IERC20 token = IERC20(boosts[id].token);
        token.transferFrom(
            boosts[id].owner,
            address(this),
            amount
        );

        boosts[id].balance += amount;
    }

    // claim for multiple accounts
    function claim(
        bytes32 id,
        address[] calldata recipients,
        bytes[] calldata signatures
    ) public {
        require(recipients.length <= 10, "Up to 10 recipients allowed");
        require(boosts[id].expires > block.timestamp, "Boost expired");

        // check signatures, revert if one is invalid or already claimed
        for (uint256 i = 0; i < recipients.length; i++) {
            require(!claimed[recipients[i]][id], "Recipient already claimed boost");

            bytes32 messageHash = keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    keccak256(abi.encodePacked(id, recipients[i]))
                )
            );

            require(
                SignatureChecker.isValidSignatureNow(
                    boosts[id].guard,
                    messageHash,
                    signatures[i]
                ),
                "Invalid signature"
            );
        }

        // mark as claimed, reduce boost balance and execute transfers
        for (uint256 i = 0; i < recipients.length; i++) {
            require(boosts[id].balance > boosts[id].amountPerAccount, "Not enough balance");

            claimed[recipients[i]][id] = true;
            boosts[id].balance -= boosts[id].amountPerAccount;
            IERC20 token = IERC20(boosts[id].token);
            token.transfer(
                recipients[i],
                boosts[id].amountPerAccount
            );
        }
    }
}

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

contract Boost {
    struct BoostSettings {
        bytes32 id;
        address token;
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
        address token,
        uint256 amountPerAccount,
        address guard,
        uint256 expires
    ) public {
        require(boosts[id].id == 0x0, "Boost already exists");
        boosts[id] = BoostSettings(
            id,
            token,
            amountPerAccount,
            guard,
            expires,
            msg.sender
        );
    }

    // token balance of boost owner
    function ownerBalance(bytes32 id) public view returns (uint256) {
        IERC20 token = IERC20(boosts[id].token);
        return token.balanceOf(boosts[id].owner);
    }
    
    // token allowance given to boost contract
    function ownerAllowance(bytes32 id) public view returns (uint256) {
        IERC20 token = IERC20(boosts[id].token);
        return token.allowance(boosts[id].owner, address(this));
    }

    // claim for multiple accounts
    function claim(
        bytes32 id,
        address[] calldata recipients,
        bytes[] calldata signatures
    ) public {
        require(recipients.length <= 10, "Too many recipients");
        require(boosts[id].expires > block.timestamp, "Boost expired");

        // check signatures, revert if one is invalid
        for (uint256 i = 0; i < recipients.length; i++) {
            require(!claimed[recipients[i]][id], "Recipient already claimed");

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

        // mark as claimed and execute transfers
        for (uint256 i = 0; i < recipients.length; i++) {
            claimed[recipients[i]][id] = true;
            IERC20 token = IERC20(boosts[id].token);
            token.transferFrom(
                boosts[id].owner,
                recipients[i],
                boosts[id].amountPerAccount
            );
        }
    }
}

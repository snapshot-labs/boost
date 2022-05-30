// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";

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
error InvalidRecipient();
error RecipientAlreadyClaimed();
error InvalidSignature();
error InsufficientBoostBalance();

contract Boost is EIP712("@snapshot-labs/boost", "0.0.1") {
  struct Claim {
    uint256 boostId;
    address recipient;
  }
  bytes32 public immutable claimStructHash = keccak256("Claim(uint256 boostId,address recipient)");

  struct BoostSettings {
    bytes32 ref; // external reference, like proposal id
    address token;
    uint256 balance;
    uint256 amountPerAccount;
    address guard;
    uint256 expires; // timestamp, maybe better block number and start/end?
    address owner;
  }

  event BoostCreated(uint256 id, BoostSettings boost);
  event BoostClaimed(uint256 id, address recipient);
  event BoostDeposited(uint256 id, address sender, uint256 amount);
  event BoostWithdrawn(uint256 id);

  uint256 public nextBoostId = 1;
  mapping(uint256 => BoostSettings) public boosts;
  mapping(address => mapping(uint256 => bool)) public claimed;

  function create(
    bytes32 ref,
    address tokenAddress,
    uint256 depositAmount,
    uint256 amountPerAccount,
    address guard,
    uint256 expires
  ) external {
    if (depositAmount == 0) revert BoostDepositRequired();
    if (amountPerAccount == 0) revert BoostAmountPerAccountRequired();
    if (depositAmount < amountPerAccount) revert BoostDepositLessThanAmountPerAccount();
    if (expires <= block.timestamp) revert BoostExpireTooLow();

    uint256 newId = nextBoostId;
    nextBoostId++;
    boosts[newId] = BoostSettings(
      ref,
      tokenAddress,
      depositAmount,
      amountPerAccount,
      guard,
      expires,
      msg.sender
    );

    IERC20 token = IERC20(tokenAddress);
    token.transferFrom(msg.sender, address(this), depositAmount);
    
    emit BoostCreated(newId, boosts[newId]);
  }

  function deposit(uint256 id, uint256 amount) public {
    if (amount == 0) revert BoostDepositRequired();
    if (boosts[id].owner == address(0)) revert BoostDoesNotExist();
    if (boosts[id].expires <= block.timestamp) revert BoostExpired();

    boosts[id].balance += amount;

    emit BoostDeposited(id, msg.sender, amount);

    IERC20 token = IERC20(boosts[id].token);
    token.transferFrom(msg.sender, address(this), amount);
  }

  function withdraw(uint256 id, address to) external {
    if (boosts[id].balance == 0) revert InsufficientBoostBalance();
    if (boosts[id].expires > block.timestamp) revert BoostNotExpired();
    if (boosts[id].owner != msg.sender) revert OnlyBoostOwner();
    if (to == address(0)) revert InvalidRecipient();

    uint256 amount = boosts[id].balance;
    boosts[id].balance = 0;

    emit BoostWithdrawn(id);

    IERC20 token = IERC20(boosts[id].token);
    token.transfer(to, amount);
  }

  // check if boost can be claimed
  modifier onlyOpenBoost(uint256 id) {
    if (boosts[id].owner == address(0)) revert BoostDoesNotExist();
    if (boosts[id].expires <= block.timestamp) revert BoostExpired();
    _;
  }

  // claim for single account
  function claim(
    uint256 id,
    address recipient,
    bytes calldata signature
  ) external onlyOpenBoost(id) {
    _claim(id, recipient, signature);
  }

  // claim for multiple accounts
  function claimMulti(
    uint256 id,
    address[] calldata recipients,
    bytes[] calldata signatures
  ) external onlyOpenBoost(id) {
    for (uint256 i = 0; i < recipients.length; i++) {
      _claim(id, recipients[i], signatures[i]);
    }
  }

  // check signature, update store, transfer tokens
  function _claim(
    uint256 id,
    address recipient,
    bytes calldata signature
  ) internal {
    if (boosts[id].balance < boosts[id].amountPerAccount) revert InsufficientBoostBalance();
    if (claimed[recipient][id]) revert RecipientAlreadyClaimed();
    if (recipient == address(0)) revert InvalidRecipient();

    bytes32 digest = _hashTypedDataV4(
      keccak256(abi.encode(claimStructHash, id, recipient))
    );

    if (!SignatureChecker.isValidSignatureNow(boosts[id].guard, digest, signature))
      revert InvalidSignature();

    claimed[recipient][id] = true;
    boosts[id].balance -= boosts[id].amountPerAccount;

    emit BoostClaimed(id, recipient);

    IERC20 token = IERC20(boosts[id].token);
    token.transfer(recipient, boosts[id].amountPerAccount);
  }
}

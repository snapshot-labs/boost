// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

interface IBoost {
  struct Boost {
    string strategyUri;
    address token;
    uint256 balance;
    address guard;
    uint256 start;
    uint256 end;
    address owner;
  }

  struct Claim {
    uint256 boostId;
    address recipient;
    uint256 amount;
  }

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

  event BoostCreated(uint256 boostId, Boost boost);
  event TokensClaimed(Claim claim);
  event TokensDeposited(uint256 boostId, address sender, uint256 amount);
  event RemainingTokensWithdrawn(uint256 boostId, uint256 amount);

  function createBoost(Boost calldata boost) external;
  function depositTokens(uint256 boostId, uint256 amount) external;
  function withdrawRemainingTokens(uint256 boostId, address to) external;
  function claimTokens(Claim calldata claim, bytes calldata signature) external;
}

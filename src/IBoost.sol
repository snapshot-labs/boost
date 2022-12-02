// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.15;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";

interface IBoost {
    struct BoostConfig {
        string strategyURI;
        IERC20 token;
        uint256 balance;
        address owner;
        address guard;
        uint48 start;
        uint48 end;
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
    error InsufficientEthFee();

    event BoostCreated(uint256 boostId, string strategyURI, BoostConfig boost);
    event TokensClaimed(Claim claim);
    event MultipleTokensClaimed(uint256 boostId, address[] recipients);
    event TokensDeposited(uint256 boostId, address sender, uint256 amount);
    event RemainingTokensWithdrawn(uint256 boostId, uint256 amount);
    event EthFeeSet(uint256 ethFee);
    event TokenFeeSet(uint256 tokenFee);
    event EthFeesCollected(address recipient);
    event TokenFeesCollected(IERC20 token, address recipient);

    function setEthFee(uint256 ethFee) external;

    function setTokenFee(uint256 tokenFee) external;

    function collectEthFees(address _recipient) external;

    function collectTokenFees(IERC20 token, address recipient) external;

    function createBoost(
        string calldata _strategyURI,
        IERC20 _token,
        uint256 _amount,
        address _owner,
        address _guard,
        uint48 _start,
        uint48 _end
    ) external payable;

    function depositTokens(uint256 boostId, uint256 amount) external;

    function withdrawRemainingTokens(uint256 boostId, address to) external;

    function claim(Claim calldata claim, bytes calldata signature) external;

    function claimMultiple(Claim[] calldata claims, bytes[] calldata signatures) external;
}

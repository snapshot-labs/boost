// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";

interface IBoost {
    struct BoostConfig {
        string strategyURI;
        IERC20 token;
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
    error InsufficientEthFee();

    event BoostCreated(uint256 boostId, BoostConfig boost);
    event TokensClaimed(Claim claim);
    event TokensDeposited(uint256 boostId, address sender, uint256 amount);
    event RemainingTokensWithdrawn(uint256 boostId, uint256 amount);

    function updateProtocolFee(uint256 newFlatEthFee, uint256 newPercentageFee) external;

    function createBoost(
        string calldata _strategyURI,
        IERC20 _token,
        uint256 _amount,
        address _guard,
        uint256 _start,
        uint256 _end,
        address _owner
    ) external payable;

    function depositTokens(uint256 boostId, uint256 amount) external;

    function withdrawRemainingTokens(uint256 boostId, address to) external;

    function claimTokens(Claim calldata claim, bytes calldata signature) external;
}

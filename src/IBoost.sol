// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";

interface IBoost {
    struct BoostConfig {
        // The token that is being distributed as a boost
        IERC20 token;
        // The current balance of the boost
        uint256 balance;
        // The boost guard, which is the address of the account that should sign claims
        address guard;
        // The start timestamp of the boost, after which claims can be made
        uint48 start;
        // The end timestamp of the boost, after which no more claims can be made
        uint48 end;
    }

    struct ClaimConfig {
        // The boost id where the claim is being made
        uint256 boostId;
        // The address of the recipient for the claim
        address recipient;
        // The amount of boost token in the claim
        uint256 amount;
        // A reference string for the claim
        bytes32 ref;
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

    /// @notice Emitted when a boost is minted
    /// @param boostId The boost id
    /// @param boost The boost config
    event Mint(uint256 boostId, BoostConfig boost);

    /// @notice Emitted when a claim is made
    /// @param claim The claim config
    event Claim(ClaimConfig claim);

    /// @notice Emitted when a boost is deposited into
    /// @param boostId The boost id
    /// @param sender The address of the depositor sender
    /// @param amount The amount of the boost token deposited
    event Deposit(uint256 boostId, address sender, uint256 amount);

    /// @notice Emitted when a boost is burned
    /// @param boostId The boost id
    event Burn(uint256 boostId);

    /// @notice Emitted when the ETH fee is set
    /// @param ethFee The ETH fee
    event EthFeeSet(uint256 ethFee);

    /// @notice Emitted when the token fee is set
    /// @param tokenFee The token fee
    event TokenFeeSet(uint256 tokenFee);

    /// @notice Emitted when ETH fees are collected
    /// @param recipient The recipient of the ETH fees
    event EthFeesCollected(address recipient);

    /// @notice Emitted when token fees are collected
    /// @param token The token of the fees
    /// @param recipient The recipient of the token fees
    event TokenFeesCollected(IERC20 token, address recipient);

    /// @notice Updates the eth protocol fee
    /// @param ethFee The new eth fee in wei
    function setEthFee(uint256 ethFee) external;

    /// @notice Updates the token protocol fee
    /// @param tokenFee The new token fee, represented as an integer denominator (100/x)%
    function setTokenFee(uint256 tokenFee) external;

    /// @notice Collects the accumulated Eth protocol fees
    /// @param recipient The address to send the fees to
    function collectEthFees(address recipient) external;

    /// @notice Collects the accumulated token protocol fees
    /// @param token The token to collect fees for
    /// @param recipient The address to send the fees to
    function collectTokenFees(IERC20 token, address recipient) external;

    /// @notice Mints a new boost
    /// @param strategyURI The URI of the boost strategy
    /// @param token The token that is being distributed as a boost
    /// @param amount The amount of the boost token that will be distributed
    /// @param owner The owner of the boost
    /// @param guard The address of the account that should sign claims
    /// @param start The start timestamp of the boost, after which claims can be made
    /// @param end The end timestamp of the boost, after which no more claims can be made
    function mint(
        string calldata strategyURI,
        IERC20 token,
        uint256 amount,
        address owner,
        address guard,
        uint48 start,
        uint48 end
    ) external payable;

    /// @notice Deposits more tokens into a boost
    /// @param boostId The boost id
    /// @param amount The amount of the token to deposit
    function deposit(uint256 boostId, uint256 amount) external;

    /// @notice Burns a boost
    /// @param boostId The boost id
    /// @param to The address to send the remaining boost balance to
    function burn(uint256 boostId, address to) external;

    /// @notice Claims a boost
    /// @param claimConfig The claim
    /// @param signature The signature of the claim, signed by the boost guard
    function claim(ClaimConfig calldata claimConfig, bytes calldata signature) external;

    /// @notice Wrapper function to claim multiple boosts in a single transaction
    /// @param claimConfigs Array of claims
    /// @param signatures Array of signatures, that correspond to the claims array
    function claimMultiple(ClaimConfig[] calldata claimConfigs, bytes[] calldata signatures) external;
}

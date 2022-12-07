// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.15;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";

interface IBoost {
    struct BoostConfig {
        IERC20 token;
        uint256 balance;
        address guard;
        uint48 start;
        uint48 end;
    }

    struct ClaimConfig {
        uint256 boostId;
        address recipient;
        uint256 amount;
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

    event Mint(uint256 boostId, BoostConfig boost);
    event Claim(ClaimConfig claim);
    event Deposit(uint256 boostId, address sender, uint256 amount);
    event Burn(uint256 boostId);
    event EthFeeSet(uint256 ethFee);
    event TokenFeeSet(uint256 tokenFee);
    event EthFeesCollected(address recipient);
    event TokenFeesCollected(IERC20 token, address recipient);

    function setEthFee(uint256 ethFee) external;

    function setTokenFee(uint256 tokenFee) external;

    function collectEthFees(address _recipient) external;

    function collectTokenFees(IERC20 token, address recipient) external;

    function mint(
        string calldata _strategyURI,
        IERC20 _token,
        uint256 _amount,
        address _owner,
        address _guard,
        uint48 _start,
        uint48 _end
    ) external payable;

    function deposit(uint256 boostId, uint256 amount) external;

    function burn(uint256 boostId, address to) external;

    function claim(ClaimConfig calldata claim, bytes calldata signature) external;

    function claimMultiple(ClaimConfig[] calldata claims, bytes[] calldata signatures) external;
}

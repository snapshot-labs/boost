// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/utils/cryptography/SignatureChecker.sol";
import "openzeppelin-contracts/utils/cryptography/draft-EIP712.sol";

import "./IBoost.sol";

contract Boost is IBoost, EIP712("boost", "1"), Ownable {
    bytes32 public immutable eip712ClaimStructHash =
        keccak256("Claim(uint256 boostId,address recipient,uint256 amount)");

    uint256 public nextBoostId = 1;
    mapping(uint256 => BoostConfig) public boosts;
    mapping(address => mapping(uint256 => bool)) public claimed;

    // Constant eth fee that is the same for all boost creators.
    uint256 public flatEthFee;
    // The fraction of the total boost deposit that is taken as a fee.
    // represented as an integer denominator (1/x)%
    uint256 public percentageFee;

    constructor(address protocolOwner, uint256 _flatEthFee, uint256 _percentageFee) {
        transferOwnership(protocolOwner);
        flatEthFee = _flatEthFee;
        percentageFee = _percentageFee;
    }

    function updateProtocolFee(uint256 newFlatEthFee, uint256 newPercentageFee) external override onlyOwner {
        flatEthFee = newFlatEthFee;
        percentageFee = newPercentageFee;
    }

    function collectEthFees() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    /// @notice Create a new boost and transfer tokens to it
    function createBoost(
        string calldata _strategyURI,
        IERC20 _token,
        uint256 _amount,
        address _guard,
        uint256 _start,
        uint256 _end,
        address _owner
    ) external payable override {
        if (_amount == 0) revert BoostDepositRequired();
        if (_end <= block.timestamp) revert BoostEndDateInPast();
        if (_start >= _end) revert BoostEndDateBeforeStart();
        if (_guard == address(0)) revert InvalidGuard();
        if (msg.value < flatEthFee) revert InsufficientEthFee();

        uint256 balance = 0;
        if (percentageFee > 0) {
            uint256 protocolFee = _amount / percentageFee;
            balance = _amount - protocolFee;
            _token.transferFrom(msg.sender, owner(), protocolFee);
        } else {
            balance = _amount;
        }

        uint256 newId = nextBoostId;
        nextBoostId++;
        boosts[newId] = BoostConfig({
            strategyURI: _strategyURI,
            token: _token,
            balance: balance,
            guard: _guard,
            start: _start,
            end: _end,
            owner: _owner
        });

        _token.transferFrom(msg.sender, address(this), balance);

        emit BoostCreated(newId, boosts[newId]);
    }

    /// @notice Top up an existing boost
    function depositTokens(uint256 boostId, uint256 _amount) external override {
        if (_amount == 0) revert BoostDepositRequired();
        if (boosts[boostId].owner == address(0)) revert BoostDoesNotExist();
        if (boosts[boostId].end <= block.timestamp) revert BoostEnded();

        uint256 balanceIncrease = 0;
        if (percentageFee > 0) {
            uint256 protocolFee = _amount / percentageFee;
            boosts[boostId].balance -= protocolFee;
            boosts[boostId].token.transferFrom(msg.sender, owner(), protocolFee);
        } else {
            balanceIncrease = _amount;
        }

        boosts[boostId].token.transferFrom(msg.sender, address(this), balanceIncrease);
        boosts[boostId].balance += balanceIncrease;
        emit TokensDeposited(boostId, msg.sender, _amount);
    }

    /// @notice Withdraw remaining tokens from an expired boost
    function withdrawRemainingTokens(uint256 boostId, address to) external override {
        if (boosts[boostId].balance == 0) revert InsufficientBoostBalance();
        if (boosts[boostId].end > block.timestamp) revert BoostNotEnded(boosts[boostId].end);
        if (boosts[boostId].owner != msg.sender) revert OnlyBoostOwner();
        if (to == address(0)) revert InvalidRecipient();

        uint256 amount = boosts[boostId].balance;
        boosts[boostId].balance = 0;

        IERC20 token = IERC20(boosts[boostId].token);
        token.transfer(to, amount);

        emit RemainingTokensWithdrawn(boostId, amount);
    }

    /// @notice Claim using a guard signature
    function claimTokens(Claim calldata claim, bytes calldata signature) external override {
        if (boosts[claim.boostId].start > block.timestamp) revert BoostNotStarted(boosts[claim.boostId].start);
        if (boosts[claim.boostId].balance < claim.amount) revert InsufficientBoostBalance();
        if (boosts[claim.boostId].end <= block.timestamp) revert BoostEnded();
        if (claimed[claim.recipient][claim.boostId]) revert RecipientAlreadyClaimed();
        if (claim.recipient == address(0)) revert InvalidRecipient();

        bytes32 digest = _hashTypedDataV4(
            keccak256(abi.encode(eip712ClaimStructHash, claim.boostId, claim.recipient, claim.amount))
        );

        if (!SignatureChecker.isValidSignatureNow(boosts[claim.boostId].guard, digest, signature))
            revert InvalidSignature();

        claimed[claim.recipient][claim.boostId] = true;
        boosts[claim.boostId].balance -= claim.amount;

        IERC20 token = IERC20(boosts[claim.boostId].token);
        token.transfer(claim.recipient, claim.amount);

        emit TokensClaimed(claim);
    }
}

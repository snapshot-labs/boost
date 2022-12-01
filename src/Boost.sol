// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

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
    mapping(address => uint256) public tokenFeeBalances;

    // Constant eth fee (in gwei) that is the same for all boost creators.
    uint256 public ethFee;
    // The fraction of the total boost deposit that is taken as a fee.
    // represented as an integer denominator (100/x)%
    uint256 public tokenFee;

    constructor(address _protocolOwner, uint256 _ethFee, uint256 _tokenFee) {
        setEthFee(_ethFee);
        setTokenFee(_tokenFee);
        transferOwnership(_protocolOwner);
    }

    function setEthFee(uint256 _ethFee) public override onlyOwner {
        ethFee = _ethFee;
        emit EthFeeSet(_ethFee);
    }

    function setTokenFee(uint256 _tokenFee) public override onlyOwner {
        tokenFee = _tokenFee;
        emit TokenFeeSet(_tokenFee);
    }

    function collectEthFees(address _recipient) external override onlyOwner {
        payable(_recipient).transfer(address(this).balance);
        emit EthFeesCollected(_recipient);
    }

    function collectTokenFees(IERC20 _token, address _recipient) external override onlyOwner {
        uint256 fees = tokenFeeBalances[address(_token)];
        tokenFeeBalances[address(_token)] = 0;
        _token.transfer(_recipient, fees);
        emit TokenFeesCollected(_token, _recipient);
    }

    /// @notice Create a new boost and transfer tokens to it
    function createBoost(
        string calldata _strategyURI,
        IERC20 _token,
        uint256 _amount,
        address _owner,
        address _guard,
        uint48 _start,
        uint48 _end
    ) external payable override {
        if (_amount == 0) revert BoostDepositRequired();
        if (_end <= block.timestamp) revert BoostEndDateInPast();
        if (_start >= _end) revert BoostEndDateBeforeStart();
        if (_guard == address(0)) revert InvalidGuard();
        if (msg.value < ethFee) revert InsufficientEthFee();

        uint256 balance = 0;
        if (tokenFee > 0) {
            uint256 tokenFeeAmount = _amount / tokenFee;
            balance = _amount - tokenFeeAmount;
            tokenFeeBalances[address(_token)] += tokenFeeAmount;
        } else {
            balance = _amount;
        }

        uint256 newId = nextBoostId;
        nextBoostId++;
        boosts[newId] = BoostConfig({
            strategyURI: _strategyURI,
            token: _token,
            balance: balance,
            owner: _owner,
            guard: _guard,
            start: _start,
            end: _end
        });

        _token.transferFrom(msg.sender, address(this), _amount);

        emit BoostCreated(newId, _strategyURI, boosts[newId]);
    }

    /// @notice Top up an existing boost
    function depositTokens(uint256 _boostId, uint256 _amount) external override {
        if (_amount == 0) revert BoostDepositRequired();
        if (boosts[_boostId].owner == address(0)) revert BoostDoesNotExist();
        if (boosts[_boostId].end <= block.timestamp) revert BoostEnded();

        uint256 balanceIncrease = 0;
        if (tokenFee > 0) {
            uint256 tokenFeeAmount = _amount / tokenFee;
            balanceIncrease = _amount - tokenFeeAmount;
            tokenFeeBalances[address(boosts[_boostId].token)] += tokenFeeAmount;
        } else {
            balanceIncrease = _amount;
        }

        boosts[_boostId].balance += balanceIncrease;
        boosts[_boostId].token.transferFrom(msg.sender, address(this), _amount);

        emit TokensDeposited(_boostId, msg.sender, balanceIncrease);
    }

    /// @notice Withdraw remaining tokens from an expired boost
    function withdrawRemainingTokens(uint256 _boostId, address _to) external override {
        if (boosts[_boostId].balance == 0) revert InsufficientBoostBalance();
        if (boosts[_boostId].end > block.timestamp) revert BoostNotEnded(boosts[_boostId].end);
        if (boosts[_boostId].owner != msg.sender) revert OnlyBoostOwner();
        if (_to == address(0)) revert InvalidRecipient();

        uint256 amount = boosts[_boostId].balance;
        boosts[_boostId].balance = 0;

        boosts[_boostId].token.transfer(_to, amount);

        emit RemainingTokensWithdrawn(_boostId, amount);
    }

    /// @notice Claim using a guard signature
    function claim(Claim calldata claim, bytes calldata signature) external override {
        _claim(claim, signature);
    }

    /// @notice Claim multiple using an array of guard signatures
    function claimMultiple(Claim[] calldata claims, bytes[] calldata signatures) external override {
        for (uint i = 0; i < signatures.length; i++) {
            _claim(claims[i], signatures[i]);
        }
    }

    function _claim(Claim memory _claim, bytes memory _signature) internal {
        if (boosts[_claim.boostId].start > block.timestamp) revert BoostNotStarted(boosts[_claim.boostId].start);
        if (boosts[_claim.boostId].balance < _claim.amount) revert InsufficientBoostBalance();
        if (boosts[_claim.boostId].end <= block.timestamp) revert BoostEnded();
        if (claimed[_claim.recipient][_claim.boostId]) revert RecipientAlreadyClaimed();
        if (_claim.recipient == address(0)) revert InvalidRecipient();

        bytes32 digest = _hashTypedDataV4(
            keccak256(abi.encode(eip712ClaimStructHash, _claim.boostId, _claim.recipient, _claim.amount))
        );

        if (!SignatureChecker.isValidSignatureNow(boosts[_claim.boostId].guard, digest, _signature))
            revert InvalidSignature();

        claimed[_claim.recipient][_claim.boostId] = true;
        boosts[_claim.boostId].balance -= _claim.amount;

        IERC20 token = IERC20(boosts[_claim.boostId].token);
        token.transfer(_claim.recipient, _claim.amount);

        emit TokensClaimed(_claim);
    }
}

/**
 * SPDX-License-Identifier: MIT
 *
 *   ____                      _
 *  |  _ \                    | |
 *  | |_) |  ___    ___   ___ | |_
 *  |  _ <  / _ \  / _ \ / __|| __|
 *  | |_) || (_) || (_) |\__ \| |_
 *  |____/  \___/  \___/ |___/ \__|
 */

pragma solidity ^0.8.15;

import "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/utils/cryptography/SignatureChecker.sol";
import "openzeppelin-contracts/utils/cryptography/EIP712.sol";
import "openzeppelin-contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import "./IBoost.sol";

/**
 * @title Boost
 * @author @SnapshotLabs - admin@snapshot.org
 * @notice Incentivize actions with ERC20 token disbursals
 */
contract Boost is IBoost, EIP712, Ownable, ERC721URIStorage {
    using SafeERC20 for IERC20;

    // The EIP712 typehash for the claim struct
    bytes32 private constant CLAIM_TYPE_HASH =
        keccak256("Claim(uint256 boostId,address recipient,uint256 amount,bytes32 ref)");

    // The id of the next boost to be minted
    uint256 public nextBoostId;

    // Mapping of boost id to boost config
    mapping(uint256 => BoostConfig) public boosts;

    // Mapping of boost id and recipient to claimed status, to prevent double claims
    mapping(bytes32 => mapping(uint256 => bool)) public claimed;

    // Mapping of token address to the total amount of fees collected in that token
    mapping(address => uint256) public tokenFeeBalances;

    // Constant eth protocol fee (in wei) that must be paid by all boost creators
    uint256 public ethFee;

    // The fraction of the total boost deposit that is taken as a protocol fee
    // represented as an integer denominator (100/x)%
    uint256 public tokenFee;

    /// @notice Initializes the boost contract
    /// @param _protocolOwner The address of the owner of the protocol
    /// @param _ethFee The eth protocol fee
    /// @param _tokenFee The token protocol fee
    constructor(
        address _protocolOwner,
        uint256 _ethFee,
        uint256 _tokenFee
    ) ERC721("boost", "BOOST") EIP712("boost", "1") {
        setEthFee(_ethFee);
        setTokenFee(_tokenFee);
        transferOwnership(_protocolOwner);
    }

    /// @inheritdoc IBoost
    function setEthFee(uint256 _ethFee) public override onlyOwner {
        ethFee = _ethFee;
        emit EthFeeSet(_ethFee);
    }

    /// @inheritdoc IBoost
    function setTokenFee(uint256 _tokenFee) public override onlyOwner {
        tokenFee = _tokenFee;
        emit TokenFeeSet(_tokenFee);
    }

    /// @inheritdoc IBoost
    function collectEthFees(address _recipient) external override onlyOwner {
        payable(_recipient).transfer(address(this).balance);
        emit EthFeesCollected(_recipient);
    }

    /// @inheritdoc IBoost
    function collectTokenFees(IERC20 _token, address _recipient) external override onlyOwner {
        uint256 fees = tokenFeeBalances[address(_token)];
        tokenFeeBalances[address(_token)] = 0;
        _token.safeTransfer(_recipient, fees);
        emit TokenFeesCollected(_token, _recipient);
    }

    /// @inheritdoc IBoost
    function mint(
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
            // The token fee is calculated and subtracted from the deposit amount to get the initial boost balance
            uint256 tokenFeeAmount = _amount / tokenFee;
            // Since tokenFeeAmount < _amount, therefore balance will never underflow
            balance = _amount - tokenFeeAmount;
            tokenFeeBalances[address(_token)] += tokenFeeAmount;
        } else {
            // When there is no token fee, the boost balance is full deposit amount
            balance = _amount;
        }

        uint256 boostId = nextBoostId;
        unchecked {
            // Overflows if 2**256 boosts are minted
            nextBoostId++;
        }

        // Minting the boost as an ERC721 and storing the config data
        _safeMint(_owner, boostId);
        _setTokenURI(boostId, _strategyURI);
        boosts[boostId] = BoostConfig({ token: _token, balance: balance, guard: _guard, start: _start, end: _end });

        // Transferring the deposit amount of the ERC20 token to the contract
        _token.safeTransferFrom(msg.sender, address(this), _amount);

        emit Mint(boostId, boosts[boostId]);
    }

    /// @inheritdoc IBoost
    function deposit(uint256 _boostId, uint256 _amount) external override {
        BoostConfig storage boost = boosts[_boostId];
        if (_amount == 0) revert BoostDepositRequired();
        if (!_exists(_boostId)) revert BoostDoesNotExist();
        if (boost.end <= block.timestamp) revert BoostEnded();

        uint256 balanceIncrease = 0;
        if (tokenFee > 0) {
            // The token fee is calculated and subtracted from the deposit amount to get the boost balance increase
            uint256 tokenFeeAmount = _amount / tokenFee;
            balanceIncrease = _amount - tokenFeeAmount;
            tokenFeeBalances[address(boost.token)] += tokenFeeAmount;
        } else {
            // When there is no token fee, the boost balance increase is the full deposit amount
            balanceIncrease = _amount;
        }

        boost.balance += balanceIncrease;
        boost.token.safeTransferFrom(msg.sender, address(this), _amount);

        emit Deposit(_boostId, msg.sender, balanceIncrease);
    }

    /// @inheritdoc IBoost
    function burn(uint256 _boostId, address _to) external override {
        BoostConfig storage boost = boosts[_boostId];
        if (!_exists(_boostId)) revert BoostDoesNotExist();
        if (boost.balance == 0) revert InsufficientBoostBalance();
        if (boost.end > block.timestamp) revert BoostNotEnded(boost.end);
        if (ownerOf(_boostId) != msg.sender) revert OnlyBoostOwner();
        if (_to == address(0)) revert InvalidRecipient();

        uint256 amount = boost.balance;

        // Transferring remaining ERC20 token balance to the designated address
        boost.token.safeTransfer(_to, amount);

        // Deleting the boost data
        _burn(_boostId);
        delete boosts[_boostId];

        emit Burn(_boostId);
    }

    /// @inheritdoc IBoost
    function claim(ClaimConfig calldata _claimConfig, bytes calldata _signature) external override {
        _claim(_claimConfig, _signature);
    }

    /// @inheritdoc IBoost
    function claimMultiple(ClaimConfig[] calldata _claimConfigs, bytes[] calldata _signatures) external override {
        for (uint i = 0; i < _signatures.length; i++) {
            _claim(_claimConfigs[i], _signatures[i]);
        }
    }

    /// @notice Claims a boost
    /// @param _claimConfig The claim
    /// @param _signature The signature of the claim, signed by the boost guard
    function _claim(ClaimConfig memory _claimConfig, bytes memory _signature) internal {
        BoostConfig storage boost = boosts[_claimConfig.boostId];
        if (boost.start > block.timestamp) revert BoostNotStarted(boost.start);
        if (boost.balance < _claimConfig.amount) revert InsufficientBoostBalance();
        if (boost.end <= block.timestamp) revert BoostEnded();
        if (claimed[_claimConfig.ref][_claimConfig.boostId]) revert RecipientAlreadyClaimed();
        if (_claimConfig.recipient == address(0)) revert InvalidRecipient();

        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    CLAIM_TYPE_HASH,
                    _claimConfig.boostId,
                    _claimConfig.recipient,
                    _claimConfig.amount,
                    _claimConfig.ref
                )
            )
        );

        if (!SignatureChecker.isValidSignatureNow(boost.guard, digest, _signature)) revert InvalidSignature();

        // Storing recipients that claimed to prevent reusing signatures
        claimed[_claimConfig.ref][_claimConfig.boostId] = true;

        // Calculating the boost balance after the claim, will not underflow as we have already checked
        // that the claim amount is less than the balance
        boost.balance -= _claimConfig.amount;

        // Transferring claim amount to recipient address
        boost.token.safeTransfer(_claimConfig.recipient, _claimConfig.amount);

        emit Claim(_claimConfig);
    }
}

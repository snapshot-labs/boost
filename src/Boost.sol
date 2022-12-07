// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/utils/cryptography/SignatureChecker.sol";
import "openzeppelin-contracts/utils/cryptography/draft-EIP712.sol";
import "openzeppelin-contracts/token/ERC721/extensions/ERC721URIStorage.sol";

import "./IBoost.sol";

contract Boost is IBoost, EIP712, Ownable, ERC721URIStorage {
    bytes32 public immutable eip712ClaimStructHash =
        keccak256("Claim(uint256 boostId,address recipient,uint256 amount,bytes32 ref)");

    uint256 public nextBoostId;

    mapping(uint256 => BoostConfig) public boosts;
    mapping(bytes32 => mapping(uint256 => bool)) public claimed;
    mapping(address => uint256) public tokenFeeBalances;

    // Constant eth fee (in gwei) that is the same for all boost creators.
    uint256 public ethFee;
    // The fraction of the total boost deposit that is taken as a fee.
    // represented as an integer denominator (100/x)%
    uint256 public tokenFee;

    constructor(
        address _protocolOwner,
        uint256 _ethFee,
        uint256 _tokenFee
    ) ERC721("boost", "BOOST") EIP712("boost", "1") {
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
            // tokenFeeAmount < _amount, therefore balance will never underflow
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
        _token.transferFrom(msg.sender, address(this), _amount);

        emit Mint(boostId, boosts[boostId]);
    }

    /// @notice Top up an existing boost
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
        boost.token.transferFrom(msg.sender, address(this), _amount);

        emit Deposit(_boostId, msg.sender, balanceIncrease);
    }

    /// @notice Withdraw remaining tokens from an expired boost
    function burn(uint256 _boostId, address _to) external override {
        BoostConfig storage boost = boosts[_boostId];
        if (!_exists(_boostId)) revert BoostDoesNotExist();
        if (boost.balance == 0) revert InsufficientBoostBalance();
        if (boost.end > block.timestamp) revert BoostNotEnded(boost.end);
        if (ownerOf(_boostId) != msg.sender) revert OnlyBoostOwner();
        if (_to == address(0)) revert InvalidRecipient();

        uint256 amount = boost.balance;

        // Transferring remaining ERC20 token balance to the designated address
        boost.token.transfer(_to, amount);

        // Deleting the boost data
        _burn(_boostId);
        delete boosts[_boostId];

        emit Burn(_boostId);
    }

    /// @notice Claim using a guard signature
    function claim(ClaimConfig calldata claim, bytes calldata signature) external override {
        _claim(claim, signature);
    }

    /// @notice Claim multiple using an array of guard signatures
    function claimMultiple(ClaimConfig[] calldata claims, bytes[] calldata signatures) external override {
        for (uint i = 0; i < signatures.length; i++) {
            _claim(claims[i], signatures[i]);
        }
    }

    function _claim(ClaimConfig memory _claim, bytes memory _signature) internal {
        BoostConfig storage boost = boosts[_claim.boostId];
        if (boost.start > block.timestamp) revert BoostNotStarted(boost.start);
        if (boost.balance < _claim.amount) revert InsufficientBoostBalance();
        if (boost.end <= block.timestamp) revert BoostEnded();
        if (claimed[_claim.ref][_claim.boostId]) revert RecipientAlreadyClaimed();
        if (_claim.recipient == address(0)) revert InvalidRecipient();

        bytes32 digest = _hashTypedDataV4(
            keccak256(abi.encode(eip712ClaimStructHash, _claim.boostId, _claim.recipient, _claim.amount, _claim.ref))
        );

        if (!SignatureChecker.isValidSignatureNow(boost.guard, digest, _signature)) revert InvalidSignature();

        // Storing recipients that claimed to prevent reusing signatures
        claimed[_claim.ref][_claim.boostId] = true;

        // Calculating the boost balance after the claim, will not underflow as we have already checked
        // that the claim amount is less than the balance
        boost.balance -= _claim.amount;

        // Transferring claim amount tp recipient address
        boost.token.transfer(_claim.recipient, _claim.amount);

        emit Claim(_claim);
    }
}

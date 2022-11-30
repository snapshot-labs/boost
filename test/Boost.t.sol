// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "./mocks/MockERC20.sol";
import "../src/Boost.sol";
import "openzeppelin-contracts/token/ERC20/IERC20.sol";

abstract contract BoostTest is Test, EIP712("boost", "1") {
    event BoostCreated(uint256 boostId, IBoost.BoostConfig boost);
    event TokensClaimed(IBoost.Claim claim);
    event TokensDeposited(uint256 boostId, address sender, uint256 amount);
    event RemainingTokensWithdrawn(uint256 boostId, uint256 amount);
    event EthFeeSet(uint256 ethFee);
    event TokenFeeSet(uint256 tokenFee);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event EthFeesCollected(address recipient);
    event TokenFeesCollected(IERC20 token, address recipient);

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

    address protocolOwner = address(0xFFFF);

    string constant boostName = "boost";
    string constant boostVersion = "1";

    Boost public boost;
    MockERC20 public token;

    uint256 public constant ownerKey = 1234;
    uint256 public constant guardKey = 5678;

    address public owner = vm.addr(ownerKey);
    address public guard = vm.addr(guardKey);

    uint256 public constant depositAmount = 100;
    string public constant strategyURI = "abc123";

    function setUp() public virtual {
        boost = new Boost(protocolOwner, 0, 0);
        token = new MockERC20("Test Token", "TEST");
    }

    /// @notice Creates a default boost
    function _createBoost() internal returns (uint256) {
        uint256 boostID = boost.nextBoostId();
        vm.prank(owner);
        boost.createBoost(
            strategyURI,
            IERC20(token),
            depositAmount,
            guard,
            block.timestamp,
            block.timestamp + 60,
            owner
        );
        return boostID;
    }

    /// @notice Creates a customizable boost
    function _createBoost(
        string memory _strategyURI,
        address _token,
        uint256 _amount,
        address _guard,
        uint256 _start,
        uint256 _end,
        address _owner,
        uint256 _ethFee
    ) internal returns (uint256) {
        uint256 boostID = boost.nextBoostId();
        vm.prank(_owner);
        vm.deal(_owner, _ethFee);
        boost.createBoost{ value: _ethFee }(_strategyURI, IERC20(_token), _amount, _guard, _start, _end, _owner);
        return boostID;
    }

    /// @notice Mint and approve token utility function
    function _mintAndApprove(address user, uint256 mintAmount, uint256 approveAmount) internal {
        token.mint(user, mintAmount);
        vm.prank(user);
        token.approve(address(boost), approveAmount);
    }

    /// @notice Generate claim eip712 signature
    function _generateClaimSignature(IBoost.Claim memory claim) internal view returns (bytes memory) {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                keccak256(
                    abi.encode(
                        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                        keccak256(bytes(boostName)),
                        keccak256(bytes(boostVersion)),
                        block.chainid,
                        address(boost)
                    )
                ),
                keccak256(
                    abi.encode(
                        keccak256("Claim(uint256 boostId,address recipient,uint256 amount)"),
                        claim.boostId,
                        claim.recipient,
                        claim.amount
                    )
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(guardKey, digest);
        return abi.encodePacked(r, s, v);
    }
}

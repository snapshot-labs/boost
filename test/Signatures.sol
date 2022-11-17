// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "openzeppelin-contracts/utils/cryptography/draft-EIP712.sol";

import "../src/IBoost.sol";

contract Signatures is Test, EIP712("boost", "1") {
    bytes32 public immutable eip712ClaimStructHash =
        keccak256("Claim(uint256 boostId,address recipient,uint256 amount)");

    function _generateClaimSignature(uint256 key, IBoost.Claim memory claim) internal returns (bytes memory) {
        bytes32 digest = _hashTypedDataV4(
            keccak256(abi.encode(eip712ClaimStructHash, claim.boostId, claim.recipient, claim.amount))
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(v, r, s);
    }
}

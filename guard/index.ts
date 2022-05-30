import { TypedDataSigner } from "@ethersproject/abstract-signer";
import { name, version } from "../package.json";

export async function generateClaimSignatures(
  addresses: string[],
  guard: TypedDataSigner,
  chainId: number,
  boostId: number,
  boostContractAddress: string
) {
  const EIP712Domain = {
    name,
    version,
    chainId: chainId,
    verifyingContract: boostContractAddress
  };

  const EIP712Types = {
    Claim: [
      { name: 'boostId', type: 'uint256' },
      { name: 'recipient', type: 'address' }
    ]
  };

  const sigs: string[] = [];

  for (const address of addresses) {
    const claim = {
      boostId,
      recipient: address
    };

    const sig = await guard._signTypedData(EIP712Domain, EIP712Types, claim);
    sigs.push(sig);
  }

  return sigs;
}

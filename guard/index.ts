import { JsonRpcSigner } from "@ethersproject/providers";
import { Contract } from "@ethersproject/contracts";
import { name, version } from "../package.json";

export async function generateClaimSignatures(
  addresses: string[],
  guard: JsonRpcSigner,
  boostId: number,
  boostContract: Contract
) {
  const network = await guard.provider?.getNetwork();
  if (!network) {
    throw new Error("Cannot derive chain id from guard's provider");
  }

  const EIP712Domain = {
    name,
    version,
    chainId: network.chainId,
    verifyingContract: boostContract.address
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

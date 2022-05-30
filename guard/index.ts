import { TypedDataSigner } from "@ethersproject/abstract-signer";
import { name, version } from "../package.json";

export async function generateClaimSignatures(
  recipients: string[],
  guard: TypedDataSigner,
  chainId: number,
  boostId: number,
  verifyingContract: string
) {
  const sigs: string[] = [];

  const EIP712Domain = {
    name,
    version,
    chainId,
    verifyingContract
  };

  const EIP712Types = {
    Claim: [
      { name: 'boostId', type: 'uint256' },
      { name: 'recipient', type: 'address' }
    ]
  };

  for (const recipient of recipients) {
    sigs.push(
      await guard._signTypedData(
        EIP712Domain,
        EIP712Types,
        { boostId, recipient }
      )
    );
  }

  return sigs;
}

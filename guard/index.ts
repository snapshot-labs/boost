import { ethers, Signer } from "ethers";

export async function generateSignatures(
  addresses: string[],
  guard: Signer,
  boostId: number
) {
  const sigs: string[] = [];

  for (const address of addresses) {
    const message = ethers.utils.arrayify(
      ethers.utils.solidityKeccak256(["uint256", "address"], [boostId, address])
    );
    sigs.push(await guard.signMessage(message));
  }

  return sigs;
}

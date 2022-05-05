import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

export async function generateSignatures(
  voters: SignerWithAddress[],
  guard: SignerWithAddress,
  boostId: string
) {
  const sigs: string[] = [];
  for (const voter of voters) {
    const message = ethers.utils.arrayify(
      ethers.utils.solidityKeccak256(
        ["bytes32", "address"],
        [boostId, voter.address]
      )
    );
    sigs.push(await guard.signMessage(message));
  }
  return sigs;
}

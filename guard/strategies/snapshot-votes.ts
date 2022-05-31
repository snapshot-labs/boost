import { BigNumber } from "ethers";
import { Claim, Strategy } from "../types";

export const snapshotVotesStrategy: Strategy = {
  generateClaims: async (boostId: BigNumber, chainId: number, recipients: string[]) => {
    const claims: Claim[] = [];
    for (const recipient of recipients) {
      claims.push({ recipient, amount: BigNumber.from(1) });
    }
    return claims;
  }
}
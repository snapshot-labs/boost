import { BigNumber } from "ethers";

export interface Claim {
  recipient: string;
  amount: BigNumber;
}

export interface Strategy {
  generateClaims(
    boostId: BigNumber,
    chainId: number,
    recipients: string[]
  ): Promise<Claim[]>;
}
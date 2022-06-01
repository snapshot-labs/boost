import { BigNumber } from "ethers";

export interface Boost {
  id: BigNumber;
  ref: string;
  token: string;
  balance: BigNumber;
  guard: string;
  expires: number;
  owner: string
}

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
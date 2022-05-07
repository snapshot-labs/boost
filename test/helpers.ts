import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ethers, network } from "hardhat";
import { TestToken } from "../typechain";

export async function expireBoost() {
  await network.provider.send("evm_increaseTime", [61]);
  await network.provider.send("evm_mine");
}

export function getBoostId(
  proposalId: string,
  token: TestToken,
  amountPerAccount: number,
  guard: SignerWithAddress,
  owner: SignerWithAddress
) {
  return ethers.utils.solidityKeccak256(
    ["bytes32", "address", "uint256", "address", "address"],
    [proposalId, token.address, amountPerAccount, guard.address, owner.address]
  );
}

import { network } from "hardhat";

export async function expireBoost() {
  await network.provider.send("evm_increaseTime", [61]);
  await network.provider.send("evm_mine");
}

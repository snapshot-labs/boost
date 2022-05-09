import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ethers, network } from "hardhat";
import { TestToken } from "../typechain";

export async function expireBoost() {
  await network.provider.send("evm_increaseTime", [61]);
  await network.provider.send("evm_mine");
}

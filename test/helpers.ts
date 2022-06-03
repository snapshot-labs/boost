import { ethers, network } from "hardhat";
import TestTokenArtifact from "./TestTokenArtifact.json";

export async function expireBoost() {
  await network.provider.send("evm_increaseTime", [61]);
  await network.provider.send("evm_mine");
}

export async function deployContracts() {
  const Boost = await ethers.getContractFactory("BoostManager");
  const TestToken = await ethers.getContractFactoryFromArtifact(TestTokenArtifact);

  const boostContract = await Boost.deploy();
  await boostContract.deployed();

  const tokenContract = await TestToken.deploy("Test Token", "TEST");
  await tokenContract.deployed();

  return { boostContract, tokenContract }
}
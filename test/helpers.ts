import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ethers, network } from "hardhat";
import TestTokenArtifact from "./TestTokenArtifact.json";

export async function advanceClock(seconds: number) {
  await network.provider.send("evm_increaseTime", [seconds]);
  await network.provider.send("evm_mine");
}

export async function deployContracts(connectedAccount: SignerWithAddress) {
  const Boost = await ethers.getContractFactory("BoostManager");
  const TestToken = await ethers.getContractFactoryFromArtifact(TestTokenArtifact);

  const boostContract = await Boost.deploy();
  await boostContract.deployed();

  const tokenContract = await TestToken.deploy("Test Token", "TEST");
  await tokenContract.deployed();

  return {
    boostContract: boostContract.connect(connectedAccount),
    tokenContract: tokenContract.connect(connectedAccount),
  }
}
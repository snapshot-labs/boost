// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat";
import BoostArtifact from "../artifacts/contracts/Boost.sol/Boost.json";

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface. If this script is run directly using `node` you may want
  // to call compile manually to make sure everything is compiled
  // await hre.run('compile');

  const Factory = await ethers.getContractFactory("SingletonFactory");
  const factory = await Factory.deploy();

  const salt = ethers.utils.id("0x0");
  const tx = await factory.deploy(salt, BoostArtifact.bytecode);
  const data = await tx.wait();

  console.log(`Boost deployed via: ${data.to} ()`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

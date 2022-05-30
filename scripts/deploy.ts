import { ethers } from "hardhat";
import BoostArtifact from "../artifacts/contracts/Boost.sol/Boost.json";
import SingleFactoryAbi from "./singletonFactoryAbi.json";

async function main() {
  const singletonFactory = await ethers.getContractAt(
    SingleFactoryAbi,
    "0xce0042B868300000d44A59004Da54A005ffdcf9f"
  );
  const salt = ethers.utils.id("0x0");
  const tx = await singletonFactory.deploy(BoostArtifact.bytecode, salt, { gasLimit: 10000000 });
  await tx.wait();
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

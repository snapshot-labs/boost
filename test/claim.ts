import { expect } from "chai";
import { ethers, network } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Boost, TestToken } from "../typechain";

describe("Claiming", function () {
  it(`succeeds for single recipient`);
  it(`succeeds for multiple recipients`);
  it(`reverts if signature was already used`);
  it(`reverts if signature is invalid`);
  it(`reverts if boost is expired`);
  it(`reverts if claim amount exceeds boost balance`);
});

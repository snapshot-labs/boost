import { expect } from "chai";
import { ethers, network } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Boost, TestToken } from "../typechain";

describe("Withdrawing", function () {
  it(`succeeds if boost is expired`);
  it(`reverts if boost is not expired`);
  it(`reverts for other accounts than the boost owner`);
  it(`reverts if boost balance is 0`);
});
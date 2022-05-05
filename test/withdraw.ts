import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Boost, TestToken } from "../typechain";
import { expireBoost, generateSignatures } from "./helpers";

describe("Withdrawing", function () {
  let owner: SignerWithAddress;
  let guard: SignerWithAddress;
  let claimer: SignerWithAddress;
  let boostContract: Boost;
  let token: TestToken;

  const boostId = ethers.utils.id("0x1");

  beforeEach(async function () {
    [owner, guard, claimer] = await ethers.getSigners();

    // deploy new boost contract
    const Boost = await ethers.getContractFactory("Boost");
    boostContract = await Boost.deploy();
    await boostContract.deployed();

    // deploy new token contract
    const TestToken = await ethers.getContractFactory("TestToken");
    token = await TestToken.deploy("Test Token", "TST");
    await token.deployed();

    await token.connect(owner).mintForSelf(100);
    await token.connect(owner).approve(boostContract.address, 100);

    const boostTx = await boostContract
      .connect(owner)
      .create(
        boostId,
        token.address,
        100,
        100,
        guard.address,
        (await ethers.provider.getBlock("latest")).timestamp + 60
      );
    await boostTx.wait();
  });

  it(`succeeds after boost is expired`, async function () {
    await expireBoost();

    await expect(() =>
      boostContract.connect(owner).withdraw(boostId)
    ).to.changeTokenBalances(token, [boostContract, owner], [-100, 100]);
  });

  it(`reverts if boost is not expired`, async function () {
    await expect(
      boostContract.connect(owner).withdraw(boostId)
    ).to.be.revertedWith("BoostNotExpired()");
  });

  it(`reverts for other accounts than the boost owner`, async function () {
    await expireBoost();

    await expect(
      boostContract.connect(guard).withdraw(boostId)
    ).to.be.revertedWith("OnlyBoostOwner()");
  });

  it(`reverts if boost balance is 0`, async function () {
    await boostContract
      .connect(claimer)
      .claim(
        boostId,
        [claimer.address],
        await generateSignatures([claimer], guard, boostId)
      );

    await expireBoost();

    await expect(
      boostContract.connect(owner).withdraw(boostId)
    ).to.be.revertedWith("InsufficientBoostBalance()");
  });
});

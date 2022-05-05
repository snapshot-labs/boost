import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Boost, TestToken } from "../typechain";
import { expireBoost, generateSignatures } from "./helpers";

describe("Claiming", function () {
  let owner: SignerWithAddress;
  let guard: SignerWithAddress;
  let claimer1: SignerWithAddress;
  let claimer2: SignerWithAddress;
  let claimer3: SignerWithAddress;
  let claimer4: SignerWithAddress;
  let boostContract: Boost;
  let token: TestToken;

  const boostId = ethers.utils.id("0x1");
  const boostIdNotExists = ethers.utils.id("0x2");
  const depositAmount = 100;
  const perAccount = 33;

  beforeEach(async function () {
    [owner, guard, claimer1, claimer2, claimer3, claimer4] =
      await ethers.getSigners();

    // deploy new boost contract
    const Boost = await ethers.getContractFactory("Boost");
    boostContract = await Boost.deploy();
    await boostContract.deployed();

    // deploy new token contract
    const TestToken = await ethers.getContractFactory("TestToken");
    token = await TestToken.deploy("Test Token", "TST");
    await token.deployed();

    await token.connect(owner).mintForSelf(depositAmount);
    await token.connect(owner).approve(boostContract.address, depositAmount);

    const boostTx = await boostContract
      .connect(owner)
      .create(
        boostId,
        token.address,
        depositAmount,
        perAccount,
        guard.address,
        (await ethers.provider.getBlock("latest")).timestamp + 60
      );
    await boostTx.wait();
  });

  it(`succeeds for single recipient`, async function () {
    const signatures = await generateSignatures([claimer1], guard, boostId);
    await expect(() =>
      boostContract
        .connect(claimer1)
        .claim(boostId, [claimer1.address], signatures)
    ).to.changeTokenBalances(token, [boostContract, claimer1], [-perAccount, perAccount]);
  });

  it(`succeeds for multiple recipients`, async function () {
    const signatures = await generateSignatures(
      [claimer1, claimer2],
      guard,
      boostId
    );
    await expect(() =>
      boostContract
        .connect(claimer1)
        .claim(boostId, [claimer1.address, claimer2.address], signatures)
    ).to.changeTokenBalances(
      token,
      [boostContract, claimer1, claimer2],
      [-(perAccount * 2), perAccount, perAccount]
    );
  });

  it(`reverts if a signature was already used`, async function () {
    const signatures = await generateSignatures([claimer1], guard, boostId);

    await boostContract
      .connect(claimer1)
      .claim(boostId, [claimer1.address], signatures);

    await expect(
      boostContract
        .connect(claimer1)
        .claim(boostId, [claimer1.address], signatures)
    ).to.be.revertedWith("RecipientAlreadyClaimed()");
  });

  it(`reverts if a signature is invalid`, async function () {
    const signatures = await generateSignatures([claimer1], guard, boostId);

    await expect(
      boostContract
        .connect(claimer2)
        .claim(boostId, [claimer2.address], signatures)
    ).to.be.revertedWith("InvalidSignature()");
  });

  it(`reverts if boost is expired`, async function () {
    const signatures = await generateSignatures([claimer1], guard, boostId);

    await expireBoost();

    await expect(
      boostContract
        .connect(claimer1)
        .claim(boostId, [claimer1.address], signatures)
    ).to.be.revertedWith("BoostExpired()");
  });

  it(`reverts if boost does not exist`, async function () {
    const signatures = await generateSignatures(
      [claimer1],
      guard,
      boostIdNotExists
    );

    await expect(
      boostContract
        .connect(claimer1)
        .claim(boostIdNotExists, [claimer1.address], signatures)
    ).to.be.revertedWith("BoostDoesNotExist()");
  });

  it(`reverts if total claim amount exceeds boost balance`, async function () {
    const signatures = await generateSignatures(
      [claimer1, claimer2, claimer3, claimer4],
      guard,
      boostId
    );

    await expect(
      boostContract
        .connect(claimer1)
        .claim(
          boostId,
          [
            claimer1.address,
            claimer2.address,
            claimer3.address,
            claimer4.address,
          ],
          signatures
        )
    ).to.be.revertedWith("InsufficientBoostBalance()");
  });
});

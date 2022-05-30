import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Boost, TestToken } from "../typechain";
import { generateClaimSignatures } from "../guard";
import { expireBoost } from "./helpers";

describe("Withdrawing", function () {
  let owner: SignerWithAddress;
  let guard: SignerWithAddress;
  let claimer: SignerWithAddress;
  let anyone: SignerWithAddress;
  let boostContract: Boost;
  let token: TestToken;
  const boostId = 1;

  beforeEach(async function () {
    [owner, guard, claimer, anyone] = await ethers.getSigners();

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

    const proposalId = ethers.utils.id("0x1");
    const boostTx = await boostContract
      .connect(owner)
      .create(
        proposalId,
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
      expect(boostContract.connect(owner).withdraw(boostId, anyone.address)).to.emit(
        boostContract,
        "BoostWithdrawn"
      )
    ).to.changeTokenBalances(token, [boostContract, anyone], [-100, 100]);
  });

  it(`reverts if boost is not expired`, async function () {
    await expect(
      boostContract.connect(owner).withdraw(boostId, owner.address)
    ).to.be.revertedWith("BoostNotExpired()");
  });

  it(`reverts for other accounts than the boost owner`, async function () {
    await expireBoost();

    await expect(
      boostContract.connect(guard).withdraw(boostId, guard.address)
    ).to.be.revertedWith("OnlyBoostOwner()");
  });

  it(`reverts if boost balance is 0`, async function () {
    const [signature] = await generateClaimSignatures(
      [claimer.address],
      guard,
      await guard.getChainId(),
      boostId,
      boostContract.address
    );
    await boostContract
      .connect(claimer)
      .claim(boostId, claimer.address, signature);

    await expireBoost();

    await expect(
      boostContract.connect(owner).withdraw(boostId, owner.address)
    ).to.be.revertedWith("InsufficientBoostBalance()");
  });
});

import { expect } from "chai";
import { ethers, network } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Boost, TestToken } from "../typechain";

describe("Depositing", function () {
  let owner: SignerWithAddress;
  let guard: SignerWithAddress;
  let boostContract: Boost;
  let token: TestToken;

  const boostId = ethers.utils.id("0x1");

  beforeEach(async function () {
    [owner, guard] = await ethers.getSigners();

    // deploy new boost contract
    const Boost = await ethers.getContractFactory("Boost");
    boostContract = await Boost.deploy();
    await boostContract.deployed();

    // deploy new token contract
    const TestToken = await ethers.getContractFactory("TestToken");
    token = await TestToken.deploy("Test Token", "TST");
    await token.deployed();
  });

  async function createBoost(amount: number) {
    const boostTx = await boostContract
      .connect(owner)
      .create(
        ethers.utils.id("0x1"),
        token.address,
        amount,
        amount,
        guard.address,
        (await ethers.provider.getBlock("latest")).timestamp + 60
      );
    await boostTx.wait();
  }

  async function mintAndApprove(
    account: SignerWithAddress,
    mintAmount: number,
    approveAmount?: number
  ) {
    await token.connect(account).mintForSelf(mintAmount);
    await token
      .connect(account)
      .approve(boostContract.address, approveAmount || mintAmount);
  }

  it(`succeeds for existing boost`, async function () {
    await mintAndApprove(owner, 200);
    await createBoost(100);

    await expect(() =>
      boostContract.connect(owner).deposit(boostId, 100)
    ).to.changeTokenBalances(token, [boostContract, owner], [100, -100]);
  });

  it(`reverts for other accounts than the boost owner`, async function () {
    await mintAndApprove(owner, 100);
    await mintAndApprove(guard, 10);
    await createBoost(100);

    await expect(
      boostContract.connect(guard).deposit(boostId, 10)
    ).to.be.revertedWith("OnlyBoostOwner()");
  });

  it(`reverts if boost does not exist`, async function () {
    await expect(
      boostContract.connect(owner).deposit(ethers.utils.id("0x1"), 10)
    ).to.be.revertedWith("BoostDoesNotExist()");
  });

  it(`reverts if boost is expired`, async function () {
    await mintAndApprove(owner, 100);
    await createBoost(90);

    await network.provider.send("evm_increaseTime", [61]);
    await network.provider.send("evm_mine");

    await expect(
      boostContract.connect(owner).deposit(boostId, 10)
    ).to.be.revertedWith("BoostExpired()");
  });

  it(`reverts if deposit exceeds token allowance`, async function () {
    await mintAndApprove(owner, 100, 50);
    await createBoost(50);

    await expect(
      boostContract.connect(owner).deposit(boostId, 10)
    ).to.be.revertedWith("ERC20: insufficient allowance");
  });

  it(`reverts if deposit exceeds token balance`, async function () {
    await mintAndApprove(owner, 100, 200);
    await createBoost(100);

    await expect(
      boostContract.connect(owner).deposit(boostId, 10)
    ).to.be.revertedWith("ERC20: transfer amount exceeds balance");
  });

  it(`reverts if deposit is 0`, async function () {
    await mintAndApprove(owner, 100);
    await createBoost(50);

    await expect(
      boostContract.connect(owner).deposit(boostId, 0)
    ).to.be.revertedWith("BoostDepositRequired()");
  });
});

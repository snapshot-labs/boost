import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Boost, TestToken } from "../typechain";
import { getBoostId } from "./helpers";

describe("Creating", function () {
  let owner: SignerWithAddress;
  let guard: SignerWithAddress;
  let boostContract: Boost;
  let token: TestToken;
  let now: number;
  let in1Minute: number;

  const proposalId = ethers.utils.id("0x1");

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

    // timestamps for expire values
    now = (await ethers.provider.getBlock("latest")).timestamp;
    in1Minute = now + 60;
  });

  it(`succeeds if boost is allowed to transfer tokens`, async function () {
    const depositAmount = 100;
    await token.connect(owner).mintForSelf(depositAmount);
    await token.connect(owner).approve(boostContract.address, depositAmount);

    await expect(() =>
      boostContract
        .connect(owner)
        .create(
          proposalId,
          token.address,
          depositAmount,
          10,
          guard.address,
          in1Minute
        )
    ).to.changeTokenBalances(
      token,
      [boostContract, owner],
      [depositAmount, -depositAmount]
    );
  });

  it(`reverts if deposit exceeds token allowance`, async function () {
    const depositAmount = 100;
    await token.connect(owner).mintForSelf(depositAmount);
    await token
      .connect(owner)
      .approve(boostContract.address, depositAmount - 1);

    await expect(
      boostContract
        .connect(owner)
        .create(
          proposalId,
          token.address,
          depositAmount,
          10,
          guard.address,
          in1Minute
        )
    ).to.be.revertedWith("ERC20: insufficient allowance");
  });

  it(`reverts if deposit exceeds token balance`, async function () {
    const depositAmount = 100;
    await token.connect(owner).mintForSelf(depositAmount - 1);
    await token.connect(owner).approve(boostContract.address, depositAmount);

    await expect(
      boostContract
        .connect(owner)
        .create(
          proposalId,
          token.address,
          depositAmount,
          10,
          guard.address,
          in1Minute
        )
    ).to.be.revertedWith("ERC20: transfer amount exceeds balance");
  });

  it(`reverts if amount per account is more than deposit`, async function () {
    const depositAmount = 100;
    const amountPerAccount = depositAmount + 1;
    await token.connect(owner).mintForSelf(amountPerAccount);
    await token.connect(owner).approve(boostContract.address, amountPerAccount);

    await expect(
      boostContract
        .connect(owner)
        .create(
          proposalId,
          token.address,
          depositAmount,
          amountPerAccount,
          guard.address,
          in1Minute
        )
    ).to.be.revertedWith("BoostDepositLessThanAmountPerAccount()");
  });

  it(`reverts if amount per account is 0`, async function () {
    const depositAmount = 100;
    await token.connect(owner).mintForSelf(depositAmount);
    await token.connect(owner).approve(boostContract.address, depositAmount);

    await expect(
      boostContract
        .connect(owner)
        .create(
          proposalId,
          token.address,
          depositAmount,
          0,
          guard.address,
          in1Minute
        )
    ).to.be.revertedWith("BoostAmountPerAccountRequired()");
  });

  it(`reverts if deposit amount is 0`, async function () {
    await expect(
      boostContract
        .connect(owner)
        .create(
          proposalId,
          token.address,
          0,
          10,
          guard.address,
          in1Minute
        )
    ).to.be.revertedWith("BoostDepositRequired()");
  });

  it(`reverts if expire is less or equal to block timestamp`, async function () {
    await expect(
      boostContract
        .connect(owner)
        .create(
          proposalId,
          token.address,
          100,
          10,
          guard.address,
          now
        )
    ).to.be.revertedWith("BoostExpireTooLow()");
  });

  it(`reverts if creating the same boost twice`, async function () {
    const depositAmount = 100;
    const amountPerAccount = 10;
    await token.connect(owner).mintForSelf(depositAmount);
    await token.connect(owner).approve(boostContract.address, depositAmount);

    const createFirst = await boostContract
      .connect(owner)
      .create(
        proposalId,
        token.address,
        depositAmount,
        amountPerAccount,
        guard.address,
        in1Minute
      );
    await createFirst.wait();

    await expect(
      boostContract
        .connect(owner)
        .create(
          proposalId,
          token.address,
          depositAmount,
          amountPerAccount,
          guard.address,
          in1Minute + 1 // expire is irrelevant
        )
    ).to.be.revertedWith("BoostAlreadyExists()");
  });

  it(`gets a boost that was created`, async function () {
    const depositAmount = 100;
    const amountPerAccount = 10;
    await token.connect(owner).mintForSelf(depositAmount);
    await token.connect(owner).approve(boostContract.address, depositAmount);

    const createTx = await boostContract
      .connect(owner)
      .create(
        proposalId,
        token.address,
        depositAmount,
        amountPerAccount,
        guard.address,
        in1Minute
      );
    await createTx.wait();

    const boostId = getBoostId(
      proposalId,
      token,
      amountPerAccount,
      guard,
      owner
    );

    const boost = await boostContract.getBoost(boostId);

    expect(boost.id).to.be.equal(boostId);
    expect(boost.token).to.be.equal(token.address);
    expect(boost.balance).to.be.equal(depositAmount);
    expect(boost.amountPerAccount).to.be.equal(amountPerAccount);
    expect(boost.guard).to.be.equal(guard.address);
    expect(boost.expires).to.be.equal(in1Minute);
    expect(boost.owner).to.be.equal(owner.address);
  });

  it(`doesn't get a boost that was not created`, async function () {
    const boostId = getBoostId(
      proposalId,
      token,
      999,
      guard,
      owner
    );
    const boost = await boostContract.getBoost(boostId);

    expect(boost.id).to.be.equal(
      "0x0000000000000000000000000000000000000000000000000000000000000000"
    );
    expect(boost.token).to.be.equal(
      "0x0000000000000000000000000000000000000000"
    );
    expect(boost.balance).to.be.equal(0);
    expect(boost.amountPerAccount).to.be.equal(0);
    expect(boost.guard).to.be.equal(
      "0x0000000000000000000000000000000000000000"
    );
    expect(boost.expires).to.be.equal(0);
    expect(boost.owner).to.be.equal(
      "0x0000000000000000000000000000000000000000"
    );
  });
});

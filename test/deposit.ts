import { expect } from "chai";
import { ethers, network } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Boost, TestToken } from "../typechain";

describe("Depositing", function () {
  let owner: SignerWithAddress;
  let guard: SignerWithAddress;
  let boostContract: Boost;
  let token: TestToken;
  let now: number;
  let in1Minute: number;

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

  it(`succeeds`, async function () {
    const boostId = ethers.utils.id("0x1");
    const initialDepositAmount = 100;
    const extraDepositAmount = 100;
    await token.connect(owner).mintForSelf(initialDepositAmount + extraDepositAmount);
    await token.connect(owner).approve(boostContract.address, initialDepositAmount + extraDepositAmount);

    const boostTx = await boostContract.connect(owner).create(
      boostId,
      token.address,
      initialDepositAmount,
      10,
      guard.address,
      in1Minute
    );
    await boostTx.wait();

    await expect(() => boostContract.connect(owner).deposit(
      boostId,
      extraDepositAmount
    )).to.changeTokenBalances(token, [boostContract, owner], [extraDepositAmount, -extraDepositAmount]);
  });

  it(`reverts for other accounts than the boost owner`, async function () {
    const boostId = ethers.utils.id("0x1");
    const initialDepositAmount = 100;
    const extraDepositAmount = 100;
    await token.connect(owner).mintForSelf(initialDepositAmount + extraDepositAmount);
    await token.connect(owner).approve(boostContract.address, initialDepositAmount + extraDepositAmount);

    const boostTx = await boostContract.connect(owner).create(
      boostId,
      token.address,
      initialDepositAmount,
      10,
      guard.address,
      in1Minute
    );
    await boostTx.wait();

    await expect(boostContract.connect(guard).deposit(
      boostId,
      extraDepositAmount
    )).to.be.revertedWith("OnlyBoostOwner()");
  });
  
  it(`reverts if boost does not exist`);
  it(`reverts if boost is expired`);
  it(`reverts if deposit exceeds token allowance`);
  it(`reverts if deposit exceeds token balance`);
  it(`reverts if deposit is 0`);
});

import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Boost } from "../typechain";
import { Contract } from "ethers";
import { deployContracts } from "./helpers";

describe("Creating", function () {
  let owner: SignerWithAddress;
  let guard: SignerWithAddress;
  let boostContract: Boost;
  let tokenContract: Contract;
  let now: number;
  let in1Minute: number;

  const proposalId = ethers.utils.id("0x1");

  beforeEach(async function () {
    [owner, guard] = await ethers.getSigners();

    ({ boostContract, tokenContract } = await deployContracts());

    // timestamps for expire values
    now = (await ethers.provider.getBlock("latest")).timestamp;
    in1Minute = now + 60;
  });

  it(`succeeds if boost is allowed to transfer tokens`, async function () {
    const depositAmount = 100;
    await tokenContract.connect(owner).mintForSelf(depositAmount);
    await tokenContract.connect(owner).approve(boostContract.address, depositAmount);

    await expect(() =>
      expect(
        boostContract
          .connect(owner)
          .create(
            proposalId,
            tokenContract.address,
            depositAmount,
            guard.address,
            in1Minute
          )
      )
        .to.emit(boostContract, "BoostCreated")
        // chaining events doesn't work yet. will be added in waffle v4
        // .to.emit(boostContract, "BoostDeposited")
    ).to.changeTokenBalances(
      tokenContract,
      [boostContract, owner],
      [depositAmount, -depositAmount]
    );
  });

  it(`reverts if deposit exceeds token allowance`, async function () {
    const depositAmount = 100;
    await tokenContract.connect(owner).mintForSelf(depositAmount);
    await tokenContract
      .connect(owner)
      .approve(boostContract.address, depositAmount - 1);

    await expect(
      boostContract
        .connect(owner)
        .create(
          proposalId,
          tokenContract.address,
          depositAmount,
          guard.address,
          in1Minute
        )
    ).to.be.revertedWith("ERC20: insufficient allowance");
  });

  it(`reverts if deposit exceeds token balance`, async function () {
    const depositAmount = 100;
    await tokenContract.connect(owner).mintForSelf(depositAmount - 1);
    await tokenContract.connect(owner).approve(boostContract.address, depositAmount);

    await expect(
      boostContract
        .connect(owner)
        .create(
          proposalId,
          tokenContract.address,
          depositAmount,
          guard.address,
          in1Minute
        )
    ).to.be.revertedWith("ERC20: transfer amount exceeds balance");
  });

  it(`reverts if deposit amount is 0`, async function () {
    await expect(
      boostContract
        .connect(owner)
        .create(proposalId, tokenContract.address, 0, guard.address, in1Minute)
    ).to.be.revertedWith("BoostDepositRequired");
  });

  it(`reverts if expire is less or equal to block timestamp`, async function () {
    await expect(
      boostContract
        .connect(owner)
        .create(proposalId, tokenContract.address, 100, guard.address, now)
    ).to.be.revertedWith("BoostExpireTooLow");
  });

  it(`gets a boost that was created`, async function () {
    const depositAmount = 100;
    await tokenContract.connect(owner).mintForSelf(depositAmount);
    await tokenContract.connect(owner).approve(boostContract.address, depositAmount);

    const createTx = await boostContract
      .connect(owner)
      .create(
        proposalId,
        tokenContract.address,
        depositAmount,
        guard.address,
        in1Minute
      );
    await createTx.wait();

    const boost = await boostContract.boosts(1);

    expect(boost.ref).to.be.equal(proposalId);
    expect(boost.token).to.be.equal(tokenContract.address);
    expect(boost.balance).to.be.equal(depositAmount);
    expect(boost.guard).to.be.equal(guard.address);
    expect(boost.expires).to.be.equal(in1Minute);
    expect(boost.owner).to.be.equal(owner.address);
  });

  it(`doesn't get a boost that was not created`, async function () {
    const boost = await boostContract.boosts(99);

    expect(boost.ref).to.be.equal(
      "0x0000000000000000000000000000000000000000000000000000000000000000"
    );
    expect(boost.token).to.be.equal(
      "0x0000000000000000000000000000000000000000"
    );
    expect(boost.balance).to.be.equal(0);
    expect(boost.guard).to.be.equal(
      "0x0000000000000000000000000000000000000000"
    );
    expect(boost.expires).to.be.equal(0);
    expect(boost.owner).to.be.equal(
      "0x0000000000000000000000000000000000000000"
    );
  });
});

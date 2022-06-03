import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BoostManager } from "../typechain";
import { generateClaimSignatures } from "@snapshot-labs/boost";
import { snapshotVotesStrategy } from "@snapshot-labs/boost/strategies/snapshot-votes";
import { advanceClock, deployContracts } from "./helpers";
import { BigNumber, Contract } from "ethers";

describe("Withdrawing", function () {
  let owner: SignerWithAddress;
  let guard: SignerWithAddress;
  let claimer: SignerWithAddress;
  let anyone: SignerWithAddress;
  let boostContract: BoostManager;
  let tokenContract: Contract;
  let now: number;
  let in1Minute: number;
  const boostId = BigNumber.from(1);
  const depositAmount = 1;

  beforeEach(async function () {
    [owner, guard, claimer, anyone] = await ethers.getSigners();

    ({ boostContract, tokenContract } = await deployContracts(owner));

    now = (await ethers.provider.getBlock("latest")).timestamp;
    in1Minute = now + 60;

    await tokenContract.mintForSelf(100);
    await tokenContract.approve(boostContract.address, 100);

    const proposalId = ethers.utils.id("0x1");
    const boostTx = await boostContract
      .create({
        ref: proposalId,
        token: tokenContract.address,
        balance: depositAmount,
        guard: guard.address,
        start: now,
        end: in1Minute,
        owner: owner.address
      });
    await boostTx.wait();
  });

  it(`succeeds after boost is expired`, async function () {
    await advanceClock(61);

    await expect(() =>
      expect(boostContract.connect(owner).withdraw(boostId, anyone.address)).to.emit(
        boostContract,
        "BoostWithdrawn"
      )
    ).to.changeTokenBalances(tokenContract, [boostContract, anyone], [-depositAmount, depositAmount]);
  });

  it(`reverts if boost is not expired`, async function () {
    await expect(
      boostContract.connect(owner).withdraw(boostId, owner.address)
    ).to.be.revertedWith(`BoostNotEnded(${in1Minute})`);
  });

  it(`reverts for other accounts than the boost owner`, async function () {
    await advanceClock(61);

    await expect(
      boostContract.connect(guard).withdraw(boostId, guard.address)
    ).to.be.revertedWith("OnlyBoostOwner()");
  });

  it(`reverts if boost balance is 0`, async function () {
    const chainId = await guard.getChainId();
    const [claim] = await snapshotVotesStrategy.generateClaims(boostId, chainId, [claimer.address]);
    const [signature] = await generateClaimSignatures(
      [claim],
      guard,
      chainId,
      boostId,
      boostContract.address
    );
    await boostContract
      .connect(claimer)
      .claimBySignature(claim, signature);

    await advanceClock(61);

    await expect(
      boostContract.connect(owner).withdraw(boostId, owner.address)
    ).to.be.revertedWith("InsufficientBoostBalance()");
  });
});

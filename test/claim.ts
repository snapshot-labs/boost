import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BoostManager } from "../typechain";
import { generateClaimSignatures } from "@snapshot-labs/boost";
import { snapshotVotesStrategy } from "@snapshot-labs/boost/strategies/snapshot-votes";
import { advanceClock, deployContracts } from "./helpers";
import { BigNumber, Contract } from "ethers";

describe("Claiming", function () {
  let owner: SignerWithAddress;
  let guard: SignerWithAddress;
  let claimer1: SignerWithAddress;
  let claimer2: SignerWithAddress;
  let claimer3: SignerWithAddress;
  let claimer4: SignerWithAddress;
  let boostContract: BoostManager;
  let tokenContract: Contract;
  let boostId: BigNumber;
  let in1Minute: number;
  let in2Minutes: number;

  const proposalId = ethers.utils.id("0x1");
  const depositAmount = 3;
  const perAccount = 1;

  beforeEach(async function () {
    [owner, guard, claimer1, claimer2, claimer3, claimer4] =
      await ethers.getSigners();

    ({ boostContract, tokenContract } = await deployContracts(owner));

    in1Minute = (await ethers.provider.getBlock("latest")).timestamp + 60;
    in2Minutes = in1Minute + 60;

    await tokenContract.mintForSelf(depositAmount);
    await tokenContract.approve(boostContract.address, depositAmount);
    const boostTx = await boostContract.create({
      ref: proposalId,
      token: tokenContract.address,
      balance: depositAmount,
      guard: guard.address,
      start: in1Minute,
      end: in2Minutes,
      owner: owner.address,
    });
    await boostTx.wait();
    boostId = BigNumber.from(1);

    boostContract = boostContract.connect(claimer1);
  });

  it(`succeeds for single recipient within boost period`, async function () {
    await advanceClock(61);
    const chainId = await guard.getChainId();
    const [claim] = await snapshotVotesStrategy.generateClaims(boostId, chainId, [claimer1.address]);
    const [signature] = await generateClaimSignatures(
      [claim],
      guard,
      chainId,
      boostId,
      boostContract.address
    );

    await expect(() =>
      expect(
        boostContract.claimBySignature(claim, signature)
      ).to.emit(boostContract, "BoostClaimed")
    ).to.changeTokenBalances(
      tokenContract,
      [boostContract, claimer1],
      [-perAccount, perAccount]
    );
  });

  it(`reverts if a signature was already used`, async function () {
    await advanceClock(61);
    const chainId = await guard.getChainId();
    const recipients = [claimer1.address];
    const [claim] = await snapshotVotesStrategy.generateClaims(boostId, chainId, recipients);
    const [signature] = await generateClaimSignatures(
      [claim],
      guard,
      chainId,
      boostId,
      boostContract.address
    );

    await boostContract
      .claimBySignature(claim, signature);

    await expect(
      boostContract
        .claimBySignature(claim, signature)
    ).to.be.revertedWith("RecipientAlreadyClaimed()");
  });

  it(`reverts if a signature is invalid`, async function () {
    await advanceClock(61);
    const chainId = await guard.getChainId();
    const recipients = [claimer1.address];
    const [claim] = await snapshotVotesStrategy.generateClaims(boostId, chainId, recipients);

    await expect(
      boostContract.claimBySignature(claim, "0x00")
    ).to.be.revertedWith("InvalidSignature()");
  });

  it(`reverts if boost has ended`, async function () {
    await advanceClock(121);
    const chainId = await guard.getChainId();
    const recipients = [claimer1.address];
    const [claim] = await snapshotVotesStrategy.generateClaims(boostId, chainId, recipients);
    const [signature] = await generateClaimSignatures(
      [claim],
      guard,
      chainId,
      boostId,
      boostContract.address
    );

    await expect(
      boostContract.claimBySignature(claim, signature)
    ).to.be.revertedWith("BoostEnded()");
  });

  it(`reverts if boost has not started yet`, async function () {
    const chainId = await guard.getChainId();
    const recipients = [claimer1.address];
    const [claim] = await snapshotVotesStrategy.generateClaims(boostId, chainId, recipients);
    const [signature] = await generateClaimSignatures(
      [claim],
      guard,
      chainId,
      boostId,
      boostContract.address
    );

    await expect(
      boostContract.claimBySignature(claim, signature)
    ).to.be.revertedWith(`BoostNotStarted(${in1Minute})`);
  });

  it(`reverts if boost does not exist`, async function () {
    await advanceClock(61);
    const chainId = await guard.getChainId();
    const recipients = [claimer1.address];
    const [claim] = await snapshotVotesStrategy.generateClaims(BigNumber.from(99), chainId, recipients);
    const [signature] = await generateClaimSignatures(
      [claim],
      guard,
      chainId,
      boostId,
      boostContract.address
    );

    await expect(
      boostContract
        .claimBySignature(claim, signature)
    ).to.be.revertedWith("BoostDoesNotExist()");
  });

  it(`reverts if total claim amount exceeds boost balance`, async function () {
    await advanceClock(61);
    const chainId = await guard.getChainId();
    const recipients = [claimer1.address, claimer2.address, claimer3.address, claimer4.address];
    const claims = await snapshotVotesStrategy.generateClaims(boostId, chainId, recipients);
    const signatures = await generateClaimSignatures(
      claims,
      guard,
      chainId,
      boostId,
      boostContract.address
    );

    await boostContract.claimBySignature(claims[0], signatures[0]);
    await boostContract.claimBySignature(claims[1], signatures[1]);
    await boostContract.claimBySignature(claims[2], signatures[2]);

    await expect(
      boostContract.claimBySignature(claims[3], signatures[3])
    ).to.be.revertedWith("InsufficientBoostBalance()");
  });
});

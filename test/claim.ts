import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Boost } from "../typechain";
import { generateClaimSignatures } from "../guard";
import { expireBoost, deployContracts } from "./helpers";
import { BigNumber, Contract } from "ethers";
import { snapshotVotesStrategy } from "../guard/strategies/snapshot-votes";

describe("Claiming", function () {
  let owner: SignerWithAddress;
  let guard: SignerWithAddress;
  let claimer1: SignerWithAddress;
  let claimer2: SignerWithAddress;
  let claimer3: SignerWithAddress;
  let claimer4: SignerWithAddress;
  let boostContract: Boost;
  let tokenContract: Contract;
  let boostId: BigNumber;

  const proposalId = ethers.utils.id("0x1");
  const depositAmount = 3;
  const perAccount = 1;

  beforeEach(async function () {
    [owner, guard, claimer1, claimer2, claimer3, claimer4] =
      await ethers.getSigners();

    ({ boostContract, tokenContract } = await deployContracts());

    await tokenContract.connect(owner).mintForSelf(depositAmount);
    await tokenContract.connect(owner).approve(boostContract.address, depositAmount);

    const boostTx = await boostContract
      .connect(owner)
      .create(
        proposalId,
        tokenContract.address,
        depositAmount,
        guard.address,
        (await ethers.provider.getBlock("latest")).timestamp + 60
      );
    await boostTx.wait();
    boostId = BigNumber.from(1);
  });

  it(`succeeds for single recipient`, async function () {
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
        boostContract
          .connect(claimer1)
          .claim(boostId, claim.recipient, claim.amount, signature)
      ).to.emit(boostContract, "BoostClaimed")
    ).to.changeTokenBalances(
      tokenContract,
      [boostContract, claimer1],
      [-perAccount, perAccount]
    );
  });

  it(`succeeds for multiple recipients`, async function () {
    const chainId = await guard.getChainId();
    const recipients = [claimer1.address, claimer2.address];
    const claims = await snapshotVotesStrategy.generateClaims(boostId, chainId, recipients);
    const signatures = await generateClaimSignatures(
      claims,
      guard,
      chainId,
      boostId,
      boostContract.address
    );

    await expect(() =>
      expect(
        boostContract
          .connect(claimer1)
          .claimMulti(
            boostId,
            claims.map(c => c.recipient),
            claims.map(c => c.amount),
            signatures
          )
      ).to.emit(boostContract, "BoostClaimed")
    ).to.changeTokenBalances(
      tokenContract,
      [boostContract, claimer1, claimer2],
      [-(perAccount * 2), perAccount, perAccount]
    );
  });

  it(`reverts if a signature was already used`, async function () {
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
      .connect(claimer1)
      .claim(boostId, claim.recipient, claim.amount, signature);

    await expect(
      boostContract
        .connect(claimer1)
        .claim(boostId, claim.recipient, claim.amount, signature)
    ).to.be.revertedWith("RecipientAlreadyClaimed()");
  });

  it(`reverts if a signature is invalid`, async function () {
    const chainId = await guard.getChainId();
    const recipients = [claimer1.address];
    const [claim] = await snapshotVotesStrategy.generateClaims(boostId, chainId, recipients);

    await expect(
      boostContract
        .connect(claimer2)
        .claim(boostId, claim.recipient, claim.amount, "0x00")
    ).to.be.revertedWith("InvalidSignature()");
  });

  it(`reverts if boost is expired`, async function () {
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

    await expireBoost();

    await expect(
      boostContract
        .connect(claimer1)
        .claim(boostId, claim.recipient, claim.amount, signature)
    ).to.be.revertedWith("BoostExpired()");
  });

  it(`reverts if boost does not exist`, async function () {
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

    const boostIdNotExists = ethers.utils.id("0x2");

    await expect(
      boostContract
        .connect(claimer1)
        .claim(boostIdNotExists, claim.recipient, claim.amount, signature)
    ).to.be.revertedWith("BoostDoesNotExist()");
  });

  it(`reverts if total claim amount exceeds boost balance`, async function () {
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

    await expect(
      boostContract
        .connect(claimer1)
        .claimMulti(
          boostId,
          claims.map(c => c.recipient),
          claims.map(c => c.amount),
          signatures
        )
    ).to.be.revertedWith("InsufficientBoostBalance()");
  });
});

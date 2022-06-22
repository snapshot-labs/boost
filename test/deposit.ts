import { expect } from "chai";
import { ethers, network } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Boost } from "../typechain";
import { BigNumber, Contract } from "ethers";
import { deployContracts } from "./helpers";

describe("Depositing", function () {
  let owner: SignerWithAddress;
  let guard: SignerWithAddress;
  let boostContract: Boost;
  let tokenContract: Contract;

  beforeEach(async function () {
    [owner, guard] = await ethers.getSigners();

    ({ boostContract, tokenContract } = await deployContracts(owner));
  });

  async function createBoost(amount: number) {
    const boostTx = await boostContract.createBoost({
      strategyURI: "abc123",
      ref: ethers.utils.id("0x1"),
      token: tokenContract.address,
      balance: amount,
      guard: guard.address,
      start: (await ethers.provider.getBlock("latest")).timestamp,
      end: (await ethers.provider.getBlock("latest")).timestamp + 60,
      owner: owner.address,
    });
    const result = await boostTx.wait();
    return result.events?.find((e) => e.event === "BoostCreated")?.args?.boostId;
  }

  async function mintAndApprove(
    account: SignerWithAddress,
    mintAmount: number,
    approveAmount?: number
  ) {
    await tokenContract.connect(account).mintForSelf(mintAmount);
    await tokenContract
      .connect(account)
      .approve(boostContract.address, approveAmount || mintAmount);
  }

  it(`succeeds for existing boost`, async function () {
    await mintAndApprove(owner, 200);
    const boostId = await createBoost(100);

    await expect(() =>
      expect(boostContract.connect(owner).depositTokens(boostId, 100)).to.emit(
        boostContract,
        "TokensDeposited"
      )
    ).to.changeTokenBalances(tokenContract, [boostContract, owner], [100, -100]);
  });

  it(`succeeds from different account`, async function () {
    await mintAndApprove(owner, 200);
    await mintAndApprove(guard, 50);
    const boostId = await createBoost(100);

    await expect(() => boostContract.connect(guard).depositTokens(boostId, 50)).to.changeTokenBalances(
      tokenContract,
      [boostContract, guard],
      [50, -50]
    );
  });

  it(`reverts if boost does not exist`, async function () {
    await expect(
      boostContract.connect(owner).depositTokens(99, 10)
    ).to.be.revertedWith("BoostDoesNotExist()");
  });

  it(`reverts if boost is expired`, async function () {
    await mintAndApprove(owner, 100);
    const boostId = await createBoost(90);

    await network.provider.send("evm_increaseTime", [61]);
    await network.provider.send("evm_mine");
    const amount = BigNumber.from(10);
    await expect(boostContract.connect(owner).depositTokens(boostId, amount)).to.be.revertedWith(
      "BoostEnded()"
    );
  });

  it(`reverts if deposit exceeds token allowance`, async function () {
    await mintAndApprove(owner, 100, 50);
    const boostId = await createBoost(50);

    await expect(boostContract.connect(owner).depositTokens(boostId, 10)).to.be.revertedWith(
      "ERC20: insufficient allowance"
    );
  });

  it(`reverts if deposit exceeds token balance`, async function () {
    await mintAndApprove(owner, 100, 200);
    const boostId = await createBoost(100);

    await expect(boostContract.connect(owner).depositTokens(boostId, 10)).to.be.revertedWith(
      "ERC20: transfer amount exceeds balance"
    );
  });

  it(`reverts if deposit is 0`, async function () {
    await mintAndApprove(owner, 100);
    const boostId = await createBoost(50);

    await expect(boostContract.connect(owner).depositTokens(boostId, 0)).to.be.revertedWith(
      "BoostDepositRequired()"
    );
  });
});

import { expect } from "chai";
import { ethers, network } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

describe("Boost", function () {
  let owner1: SignerWithAddress;
  let owner2: SignerWithAddress;
  let guard1: SignerWithAddress;
  let guard2: SignerWithAddress;
  let voter1: SignerWithAddress;
  let voter2: SignerWithAddress;
  let voter3: SignerWithAddress;
  let voter4: SignerWithAddress;
  let anyone: SignerWithAddress;
  let token1: any;
  let token2: any;
  let boostContract: any;
  let now: number;
  let in1Minute: number;
  let in2Minutes: number;
  let in3Minutes: number;

  const OWNER_1_TOKENS = 30;
  const OWNER_1_BOOST_ALLOWANCE = 30;
  const OWNER_2_TOKENS = 1000;
  const OWNER_2_BOOST_ALLOWANCE = 500;

  const BOOST_1_ID = ethers.utils.id("0x1");
  const BOOST_1_DEPOSIT = 20;
  const BOOST_1_TOPUP = 10;
  const BOOST_1_AMOUNT_PER_ACC = 10;
  const BOOST_1_DEPOSIT_END =
    BOOST_1_DEPOSIT + BOOST_1_TOPUP - BOOST_1_AMOUNT_PER_ACC * 3;

  const BOOST_2_ID = ethers.utils.id("0x2");
  const BOOST_2_DEPOSIT = 199;
  const BOOST_2_AMOUNT_PER_ACC = 2;
  const BOOST_2_DEPOSIT_END = BOOST_2_DEPOSIT;

  const BOOST_3_ID = ethers.utils.id("0x3");
  const BOOST_3_DEPOSIT = 290;
  const BOOST_3_TOPUP = 11;
  const BOOST_3_AMOUNT_PER_ACC = 33;
  const BOOST_3_DEPOSIT_END =
    BOOST_3_DEPOSIT + BOOST_3_TOPUP - BOOST_3_AMOUNT_PER_ACC * 2;

  const boostContractAs = (signer: SignerWithAddress) =>
    boostContract.connect(signer);

  // Creates a boost and expects stored parameters to be equal to the provided ones
  async function expectCreateToSucceed(params: {
    boostId: string;
    owner: SignerWithAddress;
    token: any;
    depositAmount: number;
    amountPerAcc: number;
    guard: SignerWithAddress;
    expires: number;
  }) {
    const createBoostTx = await boostContractAs(params.owner).create(
      params.boostId,
      params.token.address,
      params.depositAmount,
      params.amountPerAcc,
      params.guard.address,
      params.expires
    );
    await createBoostTx.wait();

    const boost = await boostContract.getBoost(params.boostId);

    expect(boost.id).to.equal(params.boostId, "Boost id is not correct");
    expect(boost.token).to.equal(
      params.token.address,
      "Boost token is not correct"
    );
    expect(boost.balance).to.equal(
      params.depositAmount,
      "Boost current balance is not correct"
    );
    expect(boost.amountPerAccount).to.equal(
      params.amountPerAcc,
      "Boost amount per account is not correct"
    );
    expect(boost.guard).to.equal(
      params.guard.address,
      "Boost guard is not correct"
    );
    expect(boost.expires).to.equal(
      params.expires,
      "Boost expires is not correct"
    );
    expect(boost.owner).to.equal(
      params.owner.address,
      "Boost owner is not correct"
    );
  }

  // Creates a boost and expects a revert error message
  async function expectCreateToRevert(params: {
    boostId: string;
    owner: SignerWithAddress;
    token: any;
    depositAmount: number;
    amountPerAcc: number;
    guard: SignerWithAddress;
    expires: number;
    errorMessage: string;
  }) {
    await expect(
      boostContract
        .connect(params.owner)
        .create(
          params.boostId,
          params.token.address,
          params.depositAmount,
          params.amountPerAcc,
          params.guard.address,
          params.expires
        )
    ).to.be.revertedWith(params.errorMessage);
  }

  // Claims tokens and expects balances of provided recipients to change
  async function expectClaimToSucceed(params: {
    boostId: string;
    recipients: SignerWithAddress[];
    signatures: string[];
    token: any;
    expectedBalances: number[];
  }) {
    await expect(() =>
      boostContractAs(anyone).claim(
        params.boostId,
        params.recipients.map((r) => r.address),
        params.signatures
      )
    ).to.changeTokenBalances(
      params.token,
      params.recipients,
      params.expectedBalances
    );
  }

  // Claims tokens and expects a revert error message
  async function expectClaimToRevert(params: {
    boostId: string;
    recipients: SignerWithAddress[];
    signatures: string[];
    errorMessage: string;
  }) {
    await expect(
      boostContractAs(anyone).claim(
        params.boostId,
        params.recipients.map((r) => r.address),
        params.signatures
      )
    ).to.be.revertedWith(params.errorMessage);
  }

  // Claims tokens and expects balances of provided recipients to change
  async function expectWithdrawalToSucceed(params: {
    owner: SignerWithAddress;
    boostId: string;
    token: any;
    expectedBalances: number[];
  }) {
    await expect(() =>
      boostContractAs(params.owner).withdraw(params.boostId)
    ).to.changeTokenBalances(
      params.token,
      [boostContract, params.owner],
      params.expectedBalances
    );
  }

  // Claims tokens and expects a revert error message
  async function expectWithdrawalToRevert(params: {
    owner: SignerWithAddress;
    boostId: string;
    errorMessage: string;
  }) {
    await expect(
      boostContractAs(params.owner).withdraw(params.boostId)
    ).to.be.revertedWith(params.errorMessage);
  }

  // generate guard signatures for a boost
  async function getSigs(
    voters: SignerWithAddress[],
    guard: SignerWithAddress,
    boostId: string
  ) {
    const sigs: string[] = [];
    for (const voter of voters) {
      const message = ethers.utils.arrayify(
        ethers.utils.solidityKeccak256(
          ["bytes32", "address"],
          [boostId, voter.address]
        )
      );
      sigs.push(await guard.signMessage(message));
    }
    return sigs;
  }

  // preparations
  before(async function () {
    // set times to test exipre dates
    now = (await ethers.provider.getBlock("latest")).timestamp;
    in1Minute = now + 60;
    in2Minutes = now + 120;
    in3Minutes = now + 180;

    // assign test accounts to their named variables
    [owner1, owner2, guard1, guard2, voter1, voter2, voter3, voter4, anyone] =
      await ethers.getSigners();

    // deploy boost contract
    const Boost = await ethers.getContractFactory("Boost");
    boostContract = await Boost.deploy();
    await boostContract.deployed();

    // deploy test tokens, mint owner tokens and approve boost contract
    // owner1 gets token1, owner2 gets token1 and token2
    const TestToken = await ethers.getContractFactory("TestToken");
    token1 = await TestToken.deploy("Test Token 1", "TST1");
    token2 = await TestToken.deploy("Test Token 2", "TST2");
    await token1.deployed();
    await token2.deployed();
    await token1.connect(owner1).mintForSelf(OWNER_1_TOKENS);
    await token1.connect(owner2).mintForSelf(OWNER_2_TOKENS);
    await token2.connect(owner2).mintForSelf(OWNER_2_TOKENS);
    await token1
      .connect(owner1)
      .approve(boostContract.address, OWNER_1_BOOST_ALLOWANCE);
    await token1
      .connect(owner2)
      .approve(boostContract.address, OWNER_2_BOOST_ALLOWANCE);
    await token2
      .connect(owner2)
      .approve(boostContract.address, OWNER_2_BOOST_ALLOWANCE);
  });

  it("Should not allow anyone to create a boost with 0 token1", async function () {
    await expectCreateToRevert({
      boostId: BOOST_1_ID,
      owner: anyone,
      token: token1,
      depositAmount: 0,
      amountPerAcc: BOOST_1_AMOUNT_PER_ACC,
      guard: guard1,
      expires: in1Minute,
      errorMessage: "BoostDepositRequired()",
    });
  });

  it("Should not allow anyone to create a boost with expire less than block timestamp", async function () {
    await expectCreateToRevert({
      boostId: BOOST_1_ID,
      owner: anyone,
      token: token1,
      depositAmount: BOOST_1_DEPOSIT,
      amountPerAcc: BOOST_1_AMOUNT_PER_ACC,
      guard: guard1,
      expires: now,
      errorMessage: "BoostExpireTooLow()",
    });
  });

  it("Should not allow owner1 to create a boost with token1 more than owner1 allowance", async function () {
    await expectCreateToRevert({
      boostId: BOOST_1_ID,
      owner: owner1,
      token: token1,
      depositAmount: OWNER_1_BOOST_ALLOWANCE + 1,
      amountPerAcc: BOOST_1_AMOUNT_PER_ACC,
      guard: guard1,
      expires: in1Minute,
      errorMessage: "ERC20: insufficient allowance",
    });
  });

  it(`Should allow owner1 to create boost1 with ${BOOST_1_DEPOSIT} token1 and guard1`, async function () {
    await expectCreateToSucceed({
      boostId: BOOST_1_ID,
      owner: owner1,
      token: token1,
      depositAmount: BOOST_1_DEPOSIT,
      amountPerAcc: BOOST_1_AMOUNT_PER_ACC,
      guard: guard1,
      expires: in1Minute,
    });
  });

  it("Should not allow anyone to create another boost with the same id", async function () {
    await expectCreateToRevert({
      boostId: BOOST_1_ID,
      owner: anyone,
      token: token1,
      depositAmount: BOOST_1_DEPOSIT,
      amountPerAcc: BOOST_1_AMOUNT_PER_ACC,
      guard: guard1,
      expires: in1Minute,
      errorMessage: "BoostAlreadyExists()",
    });
  });

  it(`Should allow owner2 to create boost2 with ${BOOST_2_DEPOSIT} token1 and guard1`, async function () {
    await expectCreateToSucceed({
      boostId: BOOST_2_ID,
      owner: owner2,
      token: token1,
      depositAmount: BOOST_2_DEPOSIT,
      amountPerAcc: BOOST_2_AMOUNT_PER_ACC,
      guard: guard1,
      expires: in2Minutes,
    });
  });

  it(`Should allow owner2 to create boost3 with ${BOOST_3_DEPOSIT} token2 and guard2`, async function () {
    await expectCreateToSucceed({
      boostId: BOOST_3_ID,
      owner: owner2,
      token: token2,
      depositAmount: BOOST_3_DEPOSIT,
      amountPerAcc: BOOST_3_AMOUNT_PER_ACC,
      guard: guard2,
      expires: in3Minutes,
    });
  });

  it(`Should have a contract balance of ${
    BOOST_1_DEPOSIT + BOOST_2_DEPOSIT
  } token1 and ${BOOST_3_DEPOSIT} token2`, async function () {
    const balance1 = await token1.balanceOf(boostContract.address);
    const balance2 = await token2.balanceOf(boostContract.address);

    expect(balance1).to.equal(BOOST_1_DEPOSIT + BOOST_2_DEPOSIT);
    expect(balance2).to.equal(BOOST_3_DEPOSIT);
  });

  it(`Should allow owner1 to deposit ${BOOST_1_TOPUP} more token1 for boost1`, async function () {
    await boostContractAs(owner1).deposit(BOOST_1_ID, BOOST_1_TOPUP);
    const boost = await boostContract.getBoost(BOOST_1_ID);
    const contractBalance = await token1.balanceOf(boostContract.address);

    expect(boost.balance).to.equal(
      BOOST_1_DEPOSIT + BOOST_1_TOPUP,
      "Boost balance is not correct"
    );
    expect(contractBalance).to.equal(
      BOOST_1_DEPOSIT + BOOST_1_TOPUP + BOOST_2_DEPOSIT,
      "Boost contract token balance is not correct"
    );
  });

  it(`Should not allow owner2 to deposit on boost1`, async function () {
    await expect(
      boostContractAs(owner2).deposit(BOOST_1_ID, BOOST_1_DEPOSIT)
    ).to.be.revertedWith("OnlyBoostOwner()");
  });

  it(`Should not allow to deposit on boost that does not exist`, async function () {
    await expect(
      boostContractAs(owner2).deposit(BOOST_3_ID, BOOST_3_DEPOSIT)
    ).to.be.revertedWith("BoostDoesNotExist()");
  });

  // voter1, voter2, voter3 claim from boost1
  // voter4 from boost2

  it(`Should allow to claim ${BOOST_1_AMOUNT_PER_ACC} token1 for voter1 from boost1`, async function () {
    await expectClaimToSucceed({
      boostId: BOOST_1_ID,
      recipients: [voter1],
      signatures: await getSigs([voter1], guard1, BOOST_1_ID),
      token: token1,
      expectedBalances: [BOOST_1_AMOUNT_PER_ACC],
    });
  });

  it(`Should allow to claim ${BOOST_1_AMOUNT_PER_ACC} token1 for voter2 and voter3 from boost1`, async function () {
    await expectClaimToSucceed({
      boostId: BOOST_1_ID,
      recipients: [voter2, voter3],
      signatures: await getSigs([voter2, voter3], guard1, BOOST_1_ID),
      token: token1,
      expectedBalances: [BOOST_1_AMOUNT_PER_ACC, BOOST_1_AMOUNT_PER_ACC],
    });
  });

  it(`Should allow to claim ${BOOST_2_AMOUNT_PER_ACC} token1 for voter4 from boost2`, async function () {
    await expectClaimToSucceed({
      boostId: BOOST_2_ID,
      recipients: [voter4],
      signatures: await getSigs([voter4], guard1, BOOST_2_ID),
      token: token1,
      expectedBalances: [BOOST_2_AMOUNT_PER_ACC],
    });
  });

  it(`Should not allow to claim ${BOOST_1_AMOUNT_PER_ACC} token1 for voter1 from boost1 again`, async function () {
    await expectClaimToRevert({
      boostId: BOOST_1_ID,
      recipients: [voter1],
      signatures: await getSigs([voter1], guard1, BOOST_1_ID),
      errorMessage: "RecipientAlreadyClaimed()",
    });
  });

  it(`Should not allow to claim from boost1 for anyone with guard1 sig for voter4`, async function () {
    await expectClaimToRevert({
      boostId: BOOST_1_ID,
      recipients: [anyone],
      signatures: await getSigs([voter4], guard1, BOOST_1_ID),
      errorMessage: "InvalidSignature()",
    });
  });

  it(`Should not allow to claim from boost1 for voter4 with guard2 sig for voter4`, async function () {
    await expectClaimToRevert({
      boostId: BOOST_1_ID,
      recipients: [voter4],
      signatures: await getSigs([voter4], guard2, BOOST_1_ID),
      errorMessage: "InvalidSignature()",
    });
  });

  it(`Should not allow owner1 to withdraw token1 from boost1 before expire`, async function () {
    await expectWithdrawalToRevert({
      owner: owner1,
      boostId: BOOST_1_ID,
      errorMessage: "BoostNotExpired()",
    });
  });

  it(`Should not allow owner2 to withdraw token1 from boost2 before expire`, async function () {
    await expectWithdrawalToRevert({
      owner: owner2,
      boostId: BOOST_2_ID,
      errorMessage: "BoostNotExpired()",
    });
  });

  // boost1 and boost2 expire

  it(`Should not allow to claim from boost1 for voter4 after expired`, async function () {
    await network.provider.send("evm_increaseTime", [61]);
    await network.provider.send("evm_mine");
    await expectClaimToRevert({
      boostId: BOOST_1_ID,
      recipients: [voter4],
      signatures: await getSigs([voter4], guard1, BOOST_1_ID),
      errorMessage: "BoostExpired()",
    });
  });

  it(`Should have a contract balance of ${
    BOOST_1_DEPOSIT_END + BOOST_2_DEPOSIT_END
  } token1`, async function () {
    const balance = await token1.balanceOf(boostContract.address);

    expect(balance).to.equal(BOOST_1_DEPOSIT_END + BOOST_2_DEPOSIT_END);
  });

  it(`Should not allow owner2 to withdraw token1 from boost1`, async function () {
    await expectWithdrawalToRevert({
      owner: owner2,
      boostId: BOOST_1_ID,
      errorMessage: "OnlyBoostOwner()",
    });
  });

  it(`Should not allow owner2 to withdraw token2 from boost3 before expire`, async function () {
    await expectWithdrawalToRevert({
      owner: owner2,
      boostId: BOOST_3_ID,
      errorMessage: "BoostNotExpired()",
    });
  });

  // voter1 and voter3 claim from boost3
  it(`Should allow to claim ${BOOST_3_AMOUNT_PER_ACC} token1 for voter1 and voter3 from boost3`, async function () {
    await expectClaimToSucceed({
      boostId: BOOST_1_ID,
      recipients: [voter1],
      signatures: await getSigs([voter1], guard1, BOOST_1_ID),
      token: token1,
      expectedBalances: [BOOST_1_AMOUNT_PER_ACC],
    });
  });

  it(`Should allow owner1 to withdraw ${BOOST_1_DEPOSIT_END} token1 from boost1`, async function () {
    await expectWithdrawalToSucceed({
      owner: owner1,
      boostId: BOOST_1_ID,
      token: token1,
      expectedBalances: [-BOOST_1_DEPOSIT_END, BOOST_1_DEPOSIT_END],
    });
  });

  it(`Should not allow owner1 to withdraw token1 from boost1 again`, async function () {
    await expectWithdrawalToRevert({
      owner: owner1,
      boostId: BOOST_1_ID,
      errorMessage: "InsufficientBoostBalance()",
    });
  });

  it(`Should allow owner2 to withdraw ${BOOST_2_DEPOSIT_END} token1 from boost2`, async function () {
    await expectWithdrawalToSucceed({
      owner: owner2,
      boostId: BOOST_2_ID,
      token: token1,
      expectedBalances: [-BOOST_2_DEPOSIT_END, BOOST_2_DEPOSIT_END],
    });
  });

  it(`Should allow owner2 to withdraw ${BOOST_3_DEPOSIT_END} token2 from boost3`, async function () {
    await expectWithdrawalToSucceed({
      owner: owner2,
      boostId: BOOST_3_ID,
      token: token2,
      expectedBalances: [-BOOST_3_DEPOSIT_END, BOOST_3_DEPOSIT_END],
    });
  });
});

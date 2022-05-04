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
  let nonVoter: SignerWithAddress;
  let testToken: any;
  let boostContract: any;
  let boost: any;
  let now: number;
  let inOneMinute: number;

  const PROPOSAL_ID_1 = ethers.utils.id("0x1");
  const PROPOSAL_ID_2 = ethers.utils.id("0x2");
  const TOTAL_OWNER_TOKENS = 100;
  const BOOST_ALLOWANCE = 50;
  const BOOST_DEPOSIT = 25;
  const BOOST_TOPUP = 10;
  const AMOUNT_PER_ACC = 2;
  const BOOST_DEPOSIT_END = BOOST_DEPOSIT + BOOST_TOPUP - (3 * AMOUNT_PER_ACC);

  const boostContractAs = (signer: SignerWithAddress) =>
    boostContract.connect(signer);

  // Claims tokens and expects balances of provided recipients to change
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
    boost = await boostContract.getBoost(params.boostId);

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
    expect(boost.guard).to.equal(params.guard.address, "Boost guard is not correct");
    expect(boost.expires).to.equal(params.expires, "Boost expires is not correct");
    expect(boost.owner).to.equal(params.owner.address, "Boost owner is not correct");
  }

  // Claims tokens and expects a revert error message
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
      boostContractAs(nonVoter).claim(
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
      boostContractAs(nonVoter).claim(
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
    inOneMinute = now + 60;

    // assign test accounts to their named variables
    [owner1, owner2, guard1, guard2, voter1, voter2, voter3, voter4, nonVoter] =
      await ethers.getSigners();

    // deploy boost contract
    const Boost = await ethers.getContractFactory("Boost");
    boostContract = await Boost.deploy();
    await boostContract.deployed();

    // deploy test token, mint owner tokens and approve boost contract
    const TestToken = await ethers.getContractFactory("TestToken");
    testToken = await TestToken.deploy();
    await testToken.deployed();
    await testToken.connect(owner1).mint(TOTAL_OWNER_TOKENS);
    await testToken.connect(owner2).mint(TOTAL_OWNER_TOKENS);
    await testToken
      .connect(owner1)
      .approve(boostContract.address, BOOST_ALLOWANCE);
    await testToken
      .connect(owner2)
      .approve(boostContract.address, BOOST_ALLOWANCE);
  });

  // create boost
  it("Should not allow to create a boost with amount of 0", async function () {
    await expect(
      boostContractAs(owner1).create(
        PROPOSAL_ID_1,
        testToken.address,
        0,
        AMOUNT_PER_ACC,
        guard1.address,
        inOneMinute
      )
    ).to.be.revertedWith('BoostDepositRequired()');
  });

  it("Should not allow to create a boost with expire <= block timestamp", async function () {
    await expectCreateToRevert({
      boostId: PROPOSAL_ID_1,
      owner: owner1,
      token: testToken,
      depositAmount: BOOST_DEPOSIT,
      amountPerAcc: AMOUNT_PER_ACC,
      guard: guard1,
      expires: now,
      errorMessage: "BoostExpireTooLow()",
    });
  });

  it("Should not allow to create a boost > owner1's token allowance", async function () {
    await expectCreateToRevert({
      boostId: PROPOSAL_ID_1,
      owner: owner1,
      token: testToken,
      depositAmount: BOOST_ALLOWANCE + 1,
      amountPerAcc: AMOUNT_PER_ACC,
      guard: guard1,
      expires: inOneMinute,
      errorMessage: "ERC20: insufficient allowance"
    });
  });

  it("Should allow to create a new boost as owner1, within allownace", async function () {
    await expectCreateToSucceed({
      boostId: PROPOSAL_ID_1,
      owner: owner1,
      token: testToken,
      depositAmount: BOOST_DEPOSIT,
      amountPerAcc: AMOUNT_PER_ACC,
      guard: guard1,
      expires: inOneMinute
    });
  });

  it("Should not allow to create a new boost with the same id", async function () {
    await expectCreateToRevert({
      boostId: PROPOSAL_ID_1,
      owner: owner1,
      token: testToken,
      depositAmount: BOOST_DEPOSIT,
      amountPerAcc: AMOUNT_PER_ACC,
      guard: guard1,
      expires: inOneMinute,
      errorMessage: "BoostAlreadyExists()"
    });
  });

  it(`Should have a balance of ${BOOST_DEPOSIT} tokens`, async function () {
    const balance = await testToken.balanceOf(boostContract.address);

    expect(balance).to.equal(BOOST_DEPOSIT);
  });

  // deposit
  it(`Should allow owner1 to deposit ${BOOST_TOPUP} more tokens for the boost`, async function () {
    await boostContractAs(owner1).deposit(PROPOSAL_ID_1, BOOST_TOPUP);
    boost = await boostContract.getBoost(PROPOSAL_ID_1);
    const balance = await testToken.balanceOf(boostContract.address);

    expect(boost.balance).to.equal(
      BOOST_DEPOSIT + BOOST_TOPUP,
      "Boost balance is not correct"
    );
    expect(balance).to.equal(
      BOOST_DEPOSIT + BOOST_TOPUP,
      "Boost contract token balance is not correct"
    );
  });

  it(`Should not allow others to deposit`, async function () {
    await expect(
      boostContractAs(owner2).deposit(PROPOSAL_ID_1, BOOST_DEPOSIT)
    ).to.be.revertedWith("OnlyBoostOwner()");
  });
  
  it(`Should not allow to deposit on boost that does not exist`, async function () {
    await expect(
      boostContractAs(owner2).deposit(PROPOSAL_ID_2, BOOST_DEPOSIT)
    ).to.be.revertedWith("BoostDoesNotExist()");
  });

  // claim / withdraw
  it(`Should allow to claim ${AMOUNT_PER_ACC} tokens for voter1`, async function () {
    await expectClaimToSucceed({
      boostId: boost.id,
      recipients: [voter1],
      signatures: await getSigs([voter1], guard1, boost.id),
      token: testToken,
      expectedBalances: [AMOUNT_PER_ACC],
    });
  });

  it(`Should allow to claim ${AMOUNT_PER_ACC} tokens for voter2 and voter3`, async function () {
    await expectClaimToSucceed({
      boostId: boost.id,
      recipients: [voter2, voter3],
      signatures: await getSigs([voter2, voter3], guard1, boost.id),
      token: testToken,
      expectedBalances: [AMOUNT_PER_ACC, AMOUNT_PER_ACC],
    });
  });

  it(`Should not allow to claim ${AMOUNT_PER_ACC} tokens for voter1 again`, async function () {
    await expectClaimToRevert({
      boostId: boost.id,
      recipients: [voter1],
      signatures: await getSigs([voter1], guard1, boost.id),
      errorMessage: "RecipientAlreadyClaimed()",
    });
  });

  it(`Should not allow to claim ${AMOUNT_PER_ACC} tokens for nonVoter with signature of voter4`, async function () {
    await expectClaimToRevert({
      boostId: boost.id,
      recipients: [nonVoter],
      signatures: await getSigs([voter4], guard1, boost.id),
      errorMessage: "InvalidSignature()",
    });
  });
  
  it(`Should not allow to claim ${AMOUNT_PER_ACC} tokens for voter4 with signature from guard2`, async function () {
    await expectClaimToRevert({
      boostId: boost.id,
      recipients: [voter4],
      signatures: await getSigs([voter4], guard2, boost.id),
      errorMessage: "InvalidSignature()",
    });
  });

  it(`Should not allow owner1 to withdraw ${BOOST_DEPOSIT_END} tokens before expire`, async function () {
    await expectWithdrawalToRevert({
      owner: owner1,
      boostId: boost.id,
      errorMessage: "BoostNotExpired()",
    });
  });

  it(`Should not allow to claim ${AMOUNT_PER_ACC} tokens for voter4 after boost has expired`, async function () {
    await network.provider.send("evm_increaseTime", [61]);
    await network.provider.send("evm_mine");
    await expectClaimToRevert({
      boostId: boost.id,
      recipients: [voter4],
      signatures: await getSigs([voter4], guard1, boost.id),
      errorMessage: "BoostExpired()",
    });
  });

  it(`Should have a balance of ${BOOST_DEPOSIT_END} tokens`, async function () {
    const balance = await testToken.balanceOf(boostContract.address);

    expect(balance).to.equal(BOOST_DEPOSIT_END);
  });
  
  it(`Should not allow owner2 to withdraw ${BOOST_DEPOSIT_END} tokens`, async function () {
    await expectWithdrawalToRevert({
      owner: owner2,
      boostId: boost.id,
      errorMessage: "OnlyBoostOwner()",
    });
  });

  it(`Should allow owner1 to withdraw ${BOOST_DEPOSIT_END} tokens`, async function () {
    await expectWithdrawalToSucceed({
      owner: owner1,
      boostId: boost.id,
      token: testToken,
      expectedBalances: [-BOOST_DEPOSIT_END, BOOST_DEPOSIT_END],
    });
  });

  it(`Should not allow owner1 to withdraw ${BOOST_DEPOSIT_END} tokens again`, async function () {
    await expectWithdrawalToRevert({
      owner: owner1,
      boostId: boost.id,
      errorMessage: "InsufficientBoostBalance()",
    });
  });
});

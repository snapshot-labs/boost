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
  const TOTAL_OWNER_TOKENS = 100;
  const BOOST_ALLOWANCE = 50;
  const BOOST_DEPOSIT = 25;
  const BOOST_TOPUP = 10;
  const AMOUNT_PER_ACC = 2;

  const boostContractAs = (signer: SignerWithAddress) =>
    boostContract.connect(signer);

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
    ).to.be.revertedWith("Deposit amount must be > 0");
  });

  it("Should not allow to create a boost with expire <= block timestamp", async function () {
    await expect(
      boostContractAs(owner1).create(
        PROPOSAL_ID_1,
        testToken.address,
        BOOST_DEPOSIT,
        AMOUNT_PER_ACC,
        guard1.address,
        now
      )
    ).to.be.revertedWith("Expire must be > block timestamp");
  });

  it("Should not allow to create a boost > owner1's token allowance", async function () {
    await expect(
      boostContractAs(owner1).create(
        PROPOSAL_ID_1,
        testToken.address,
        BOOST_ALLOWANCE + 1,
        AMOUNT_PER_ACC,
        guard1.address,
        inOneMinute
      )
    ).to.be.revertedWith("ERC20: insufficient allowance");
  });

  it("Should allow to create a new boost as owner1, within allownace", async function () {
    const createBoostTx = await boostContractAs(owner1).create(
      PROPOSAL_ID_1,
      testToken.address,
      BOOST_DEPOSIT,
      AMOUNT_PER_ACC,
      guard1.address,
      inOneMinute
    );
    await createBoostTx.wait();
    boost = await boostContract.getBoost(PROPOSAL_ID_1);

    expect(boost.id).to.equal(PROPOSAL_ID_1, "Boost id is not correct");
    expect(boost.token).to.equal(
      testToken.address,
      "Boost token is not correct"
    );
    expect(boost.balance).to.equal(
      BOOST_DEPOSIT,
      "Boost current balance is not correct"
    );
    expect(boost.amountPerAccount).to.equal(
      AMOUNT_PER_ACC,
      "Boost amount per account is not correct"
    );
    expect(boost.guard).to.equal(guard1.address, "Boost guard is not correct");
    expect(boost.expires).to.equal(inOneMinute, "Boost expires is not correct");
    expect(boost.owner).to.equal(owner1.address, "Boost owner is not correct");
  });

  it("Should not allow to create a new boost with the same id", async function () {
    await expect(
      boostContract
        .connect(owner1)
        .create(
          PROPOSAL_ID_1,
          testToken.address,
          BOOST_DEPOSIT,
          AMOUNT_PER_ACC,
          guard1.address,
          inOneMinute
        )
    ).to.be.revertedWith("Boost already exists");
  });

  it(`Should have a balance of ${BOOST_DEPOSIT} tokens`, async function () {
    const balance = await testToken.balanceOf(boostContract.address);

    expect(balance).to.equal(BOOST_DEPOSIT);
  });

  // deposit
  it(`Should allow owner1 to deposit ${BOOST_TOPUP} tokens for the boost`, async function () {
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
    ).to.be.revertedWith("Only owner can deposit");
  });

  // claim
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
      errorMessage: "Recipient already claimed",
    });
  });

  it(`Should not allow to claim ${AMOUNT_PER_ACC} tokens for nonVoter with signature of voter4`, async function () {
    await expectClaimToRevert({
      boostId: boost.id,
      recipients: [nonVoter],
      signatures: await getSigs([voter4], guard1, boost.id),
      errorMessage: "Invalid signature",
    });
  });

  it(`Should not allow to claim ${AMOUNT_PER_ACC} tokens for voter4 after boost has expired`, async function () {
    await network.provider.send("evm_increaseTime", [61]);
    await network.provider.send("evm_mine");
    await expectClaimToRevert({
      boostId: boost.id,
      recipients: [voter4],
      signatures: await getSigs([voter4], guard1, boost.id),
      errorMessage: "Boost expired",
    });
  });
});

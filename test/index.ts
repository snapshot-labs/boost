import { expect } from "chai";
import { ethers, network } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

describe("Boost", function () {
  let owner: SignerWithAddress;
  let guard: SignerWithAddress;
  let voter1: SignerWithAddress;
  let voter2: SignerWithAddress;
  let voter3: SignerWithAddress;
  let voter4: SignerWithAddress;
  let voter5: SignerWithAddress;
  let nonVoter: SignerWithAddress;
  let testToken: any;
  let boostContract: any;
  let boost1: any;
  let now: number;
  let inOneMinute: number;

  const PROPOSAL_ID_1 = ethers.utils.id("0x1");
  const PROPOSAL_ID_2 = ethers.utils.id("0x2");
  const TOTAL_OWNER_TOKENS = 100;
  const INITIAL_ALLOWANCE = 50;
  const AMOUNT_PER_ACC = 2;

  // Claims tokens and expects balances of provided recipients to change
  async function canClaim(
    boostId: string,
    actor: SignerWithAddress,
    recipients: SignerWithAddress[],
    signatures: string[],
    token: any,
    expectedBalances: number[]
  ) {
    await expect(() =>
      boostContract.connect(actor).claim(
        boostId,
        recipients.map((r) => r.address),
        signatures
      )
    ).to.changeTokenBalances(token, recipients, expectedBalances);
  }

  // Claims tokens and expects a revert error message
  async function cantClaim(
    boostId: string,
    actor: SignerWithAddress,
    recipients: SignerWithAddress[],
    signatures: string[],
    errorMessage: string
  ) {
    await expect(
      boostContract.connect(actor).claim(
        boostId,
        recipients.map((r) => r.address),
        signatures
      )
    ).to.be.revertedWith(errorMessage);
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
    [owner, guard, voter1, voter2, voter3, voter4, voter5, nonVoter] =
      await ethers.getSigners();

    // deploy boost contract
    const Boost = await ethers.getContractFactory("Boost");
    boostContract = await Boost.deploy();
    await boostContract.deployed();

    // deploy test token, mint owner tokens and approve boost contract
    const TestToken = await ethers.getContractFactory("TestToken");
    testToken = await TestToken.deploy();
    await testToken.deployed();
    await testToken.connect(owner).mint(TOTAL_OWNER_TOKENS);
    await testToken
      .connect(owner)
      .approve(boostContract.address, INITIAL_ALLOWANCE);
  });

  it("Should not allow to create a boost with amount of 0", async function () {
    await expect(
      boostContract
        .connect(owner)
        .create(
          PROPOSAL_ID_1,
          testToken.address,
          0,
          AMOUNT_PER_ACC,
          guard.address,
          inOneMinute
        )
    ).to.be.revertedWith("Deposit amount must be > 0");
  });

  it("Should not allow to create a boost with expire <= block timestamp", async function () {
    await expect(
      boostContract
        .connect(owner)
        .create(
          PROPOSAL_ID_1,
          testToken.address,
          INITIAL_ALLOWANCE,
          AMOUNT_PER_ACC,
          guard.address,
          now
        )
    ).to.be.revertedWith("Expire must be > block timestamp");
  });

  it("Should not allow to create a boost > token allowance", async function () {
    await expect(
      boostContract
        .connect(owner)
        .create(
          PROPOSAL_ID_1,
          testToken.address,
          INITIAL_ALLOWANCE + 1,
          AMOUNT_PER_ACC,
          guard.address,
          inOneMinute
        )
    ).to.be.revertedWith("ERC20: insufficient allowance");
  });

  it("Should allow to create a new boost as owner, within owner's allownace", async function () {
    const createBoostTx = await boostContract
      .connect(owner)
      .create(
        PROPOSAL_ID_1,
        testToken.address,
        INITIAL_ALLOWANCE / 2,
        AMOUNT_PER_ACC,
        guard.address,
        inOneMinute
      );
    await createBoostTx.wait();

    boost1 = await boostContract.getBoost(PROPOSAL_ID_1);
    expect(boost1.id).to.equal(PROPOSAL_ID_1, "Boost id is not correct");
    expect(boost1.token).to.equal(
      testToken.address,
      "Boost token is not correct"
    );
    expect(boost1.balance).to.equal(
      INITIAL_ALLOWANCE / 2,
      "Boost current balance is not correct"
    );
    expect(boost1.amountPerAccount).to.equal(
      AMOUNT_PER_ACC,
      "Boost amount per account is not correct"
    );
    expect(boost1.guard).to.equal(guard.address, "Boost guard is not correct");
    expect(boost1.expires).to.equal(
      inOneMinute,
      "Boost expires is not correct"
    );
    expect(boost1.owner).to.equal(owner.address, "Boost owner is not correct");
  });

  it(`Should have a balance of ${INITIAL_ALLOWANCE / 2} tokens`, async function () {
    const balance = await testToken.balanceOf(boostContract.address);

    expect(balance).to.equal(INITIAL_ALLOWANCE / 2);
  });

  it(`Should allow owner to deposit for the boost`, async function () {
    await boostContract.connect(owner).deposit(PROPOSAL_ID_1, 10);
    boost1 = await boostContract.getBoost(PROPOSAL_ID_1);
    const balance = await testToken.balanceOf(boostContract.address);

    expect(boost1.balance).to.equal(35, "Boost balance is not correct");
    expect(balance).to.equal(35, "Boost token balance is not correct");
  });

  it(`Should not allow others to deposit`, async function () {
    await expect(
      boostContract.connect(guard).deposit(PROPOSAL_ID_1, INITIAL_ALLOWANCE / 2)
    ).to.be.revertedWith("Only owner can deposit");
  });

  it(`Should allow voter1 to claim ${AMOUNT_PER_ACC} tokens for voter1 from boost 1`, async function () {
    await canClaim(
      boost1.id,
      voter1,
      [voter1],
      await getSigs([voter1], guard, boost1.id),
      testToken,
      [AMOUNT_PER_ACC]
    );
  });

  it(`Should not allow voter1 to claim ${AMOUNT_PER_ACC} tokens for voter1 from boost 1 again`, async function () {
    await cantClaim(
      boost1.id,
      voter1,
      [voter1],
      await getSigs([voter1], guard, boost1.id),
      "Recipient already claimed"
    );
  });

  it(`Should allow voter1 to claim ${AMOUNT_PER_ACC} tokens for voter2 and voter3 from boost 1`, async function () {
    await canClaim(
      boost1.id,
      voter1,
      [voter2, voter3],
      await getSigs([voter2, voter3], guard, boost1.id),
      testToken,
      [AMOUNT_PER_ACC, AMOUNT_PER_ACC]
    );
  });

  it(`Should not allow nonVoter to claim ${AMOUNT_PER_ACC} tokens for nonVoter with signature of voter5 from boost 1`, async function () {
    await cantClaim(
      boost1.id,
      nonVoter,
      [nonVoter],
      await getSigs([voter5], guard, boost1.id),
      "Invalid signature"
    );
  });

  it(`Should allow nonVoter to claim ${AMOUNT_PER_ACC} tokens for voter4 with signature of voter 4 from boost 1`, async function () {
    await canClaim(
      boost1.id,
      nonVoter,
      [voter4],
      await getSigs([voter4], guard, boost1.id),
      testToken,
      [AMOUNT_PER_ACC, AMOUNT_PER_ACC]
    );
  });

  it(`Should not allow voter5 to claim ${AMOUNT_PER_ACC} tokens from boost 1 after boost has expired`, async function () {
    await network.provider.send("evm_increaseTime", [61]);
    await network.provider.send("evm_mine");
    await cantClaim(
      boost1.id,
      voter5,
      [voter5],
      await getSigs([voter5], guard, boost1.id),
      "Boost expired"
    );
  });

  it("Should not allow to create a new boost with the same id", async function () {
    await expect(
      boostContract
        .connect(owner)
        .create(
          PROPOSAL_ID_1,
          testToken.address,
          INITIAL_ALLOWANCE,
          AMOUNT_PER_ACC,
          guard.address,
          inOneMinute
        )
    ).to.be.revertedWith("Boost already exists");
  });
});

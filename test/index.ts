import { expect } from "chai";
import { ethers, network } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Boost, TestToken } from "../typechain";

describe("Boost", function () {
  let owner: SignerWithAddress;
  let guard: SignerWithAddress;
  let voter1: SignerWithAddress;
  let voter2: SignerWithAddress;
  let voter3: SignerWithAddress;
  let voter4: SignerWithAddress;
  let voter5: SignerWithAddress;
  let nonVoter: SignerWithAddress;
  let testToken: TestToken;
  let boostContract: Boost;
  let boost1: any;
  let boost2: any;

  const PROPOSAL_ID_1 = ethers.utils.id("0x1");
  const PROPOSAL_ID_2 = ethers.utils.id("0x2");
  const AMOUNT_PER_ACC = 2;
  const AMOUNT_PER_ACC_HIGH = 10;

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

  // check a boost's owner's token balance and allowance
  async function expectOwnerBalanceAndAllowance(boostId: string, expectedBalance: number, expectedAllowance: number) {
    const balance = await boostContract.ownerBalance(boostId);
    const allowance = await boostContract.ownerAllowance(boostId);
    
    expect(balance).to.deep.equal(expectedBalance);
    expect(allowance).to.deep.equal(expectedAllowance);
  }

  // generate guard signatures for a boost
  async function getSigs(voters: SignerWithAddress[], guard: SignerWithAddress, boostId: string) {
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
    // assign test accounts to their named variables
    [owner, guard, voter1, voter2, voter3, voter4, voter5, nonVoter] =
      await ethers.getSigners();

    // deploy boost contract
    const Boost = await ethers.getContractFactory("Boost");
    boostContract = await Boost.deploy();
    await boostContract.deployed();

    // deploy test token (mints 100 to owner)
    const TestToken = await ethers.getContractFactory("TestToken");
    testToken = await TestToken.deploy();
    await testToken.deployed();

    // allow boost contract to spend test token on behalf of owner
    await testToken.connect(owner).approve(boostContract.address, 50);
  });

  it("Should not be able to create a boost with expire date <= current block timestamp", async function () {
    // set expire date to 1 minute from now
    const expire = (await ethers.provider.getBlock("latest")).timestamp;

    await expect(
      boostContract
        .connect(owner)
        .create(PROPOSAL_ID_1, testToken.address, 0, AMOUNT_PER_ACC, guard.address, expire)
    ).to.be.revertedWith("Expire date must be after current block timestamp");
  });

  it("Should create a new allowance-based boost as owner", async function () {
    // set expire date to 1 minute from now
    const expire = (await ethers.provider.getBlock("latest")).timestamp + 60;

    const createBoostTx = await boostContract
      .connect(owner)
      .create(PROPOSAL_ID_1, testToken.address, 0, AMOUNT_PER_ACC, guard.address, expire);
    await createBoostTx.wait();

    boost1 = await boostContract.getBoost(PROPOSAL_ID_1);
    expect(boost1.id).to.equal(PROPOSAL_ID_1, "Boost id is not correct");
    expect(boost1.token).to.equal(testToken.address, "Boost token is not correct");
    expect(boost1.depositAmount).to.equal(0, "Boost deposit is not correct");
    expect(boost1.amountPerAccount).to.equal(AMOUNT_PER_ACC, "Boost amount per account is not correct");
    expect(boost1.guard).to.equal(guard.address, "Boost guard is not correct");
    expect(boost1.expires).to.equal(expire, "Boost expires is not correct");
    expect(boost1.owner).to.equal(owner.address, "Boost owner is not correct");
  });

  it("Should have an allowance over 50 of owner's tokens and owner should have a balance of 100", async function () {
    await expectOwnerBalanceAndAllowance(boost1.id, 100, 50);
  });

  it(`Should allow voter1 to claim ${AMOUNT_PER_ACC} tokens for voter1 from boost 1`, async function () {
    await canClaim(boost1.id, voter1, [voter1], await getSigs([voter1], guard, boost1.id), testToken, [
      AMOUNT_PER_ACC
    ]);
  });

  it(`Should not allow voter1 to claim ${AMOUNT_PER_ACC} tokens for voter1 again from boost 1`, async function () {
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

  it("Should not allow voter5 to claim from boost 1 while owner has revoked allowance", async function () {
    // revoke allowance
    const ownerAllowance = await boostContract.ownerAllowance(boost1.id);
    await testToken.connect(owner).approve(boostContract.address, 0);

    await cantClaim(
      boost1.id,
      voter5,
      [voter5],
      await getSigs([voter5], guard, boost1.id),
      "ERC20: insufficient allowance"
    );

    // regrant allowance
    await testToken.connect(owner).approve(boostContract.address, ownerAllowance);
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

  it("Should have an allowance over 42 of owner's tokens and owner should have a balance of 92", async function () {
    await expectOwnerBalanceAndAllowance(boost1.id, 92, 42);
  });

  it("Should not create a new boost with the same id", async function () {
    // set expire date to 1 minute from now
    const expire = (await ethers.provider.getBlock("latest")).timestamp + 60;

    await expect(
      boostContract
        .connect(owner)
        .create(PROPOSAL_ID_1, testToken.address, 0, AMOUNT_PER_ACC, guard.address, expire)
    ).to.be.revertedWith("Boost already exists");
  });

  it("Should not be able to create a new boost with 100 tokens deposit, because of insufficiant allownace", async function () {
    // set expire date to 1 minute from now
    const expire = (await ethers.provider.getBlock("latest")).timestamp + 60;

    await expect(
      boostContract
        .connect(owner)
        .create(PROPOSAL_ID_2, testToken.address, 100, AMOUNT_PER_ACC, guard.address, expire)
    ).to.be.revertedWith("ERC20: insufficient allowance");
  });

  it("Should create a new boost as owner with a 42 token deposit", async function () {
    // set expire date to 1 minute from now
    const expire = (await ethers.provider.getBlock("latest")).timestamp + 60;

    const createBoostTx = await boostContract
      .connect(owner)
      .create(PROPOSAL_ID_2, testToken.address, 42, AMOUNT_PER_ACC_HIGH, guard.address, expire);
    await createBoostTx.wait();

    boost2 = await boostContract.getBoost(PROPOSAL_ID_2);
    expect(boost2.id).to.equal(PROPOSAL_ID_2, "Boost id is not correct");
    expect(boost2.token).to.equal(testToken.address, "Boost token is not correct");
    expect(boost2.depositAmount).to.equal(42, "Boost deposit is not correct");
    expect(boost2.amountPerAccount).to.equal(AMOUNT_PER_ACC_HIGH, "Boost amount per account is not correct");
    expect(boost2.guard).to.equal(guard.address, "Boost guard is not correct");
    expect(boost2.expires).to.equal(expire, "Boost expires is not correct");
    expect(boost2.owner).to.equal(owner.address, "Boost owner is not correct");
  });

  it("Should have an allowance over 0 of owner's tokens and owner should have a balance of 50", async function () {
    await expectOwnerBalanceAndAllowance(boost1.id, 50, 0);
  });

  it("Should have a balance of 42 tokens", async function () {
    const balance = await testToken.balanceOf(boostContract.address);

    expect(balance).to.equal(42, "Boost contract token balance is not correct");
  });

  it(`Should allow voter1 to claim ${AMOUNT_PER_ACC_HIGH} tokens for voter1 from boost 2`, async function () {
    await canClaim(boost2.id, voter1, [voter1], await getSigs([voter1], guard, boost2.id), testToken, [
      AMOUNT_PER_ACC_HIGH
    ]);
  });
});

import { expect } from "chai";
import { ethers, network } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

describe("Boost", function () {
  let owner: any;
  let guard: any;
  let voter1: any;
  let voter2: any;
  let voter3: any;
  let voter4: any;
  let voter5: any;
  let nonVoter: any;
  let testToken: any;
  let boostContract: any;
  let newBoost: any;

  const PROPOSAL_ID = ethers.utils.id("0x1");
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
    ).to.changeTokenBalances(token, [actor, ...recipients], expectedBalances);
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

  it("Should create a new boost as owner", async function () {
    // set expire date to 1 minute from now
    const expire = (await ethers.provider.getBlock("latest")).timestamp + 60;

    const createBoostTx = await boostContract
      .connect(owner)
      .create(PROPOSAL_ID, testToken.address, AMOUNT_PER_ACC, guard.address, expire);
    await createBoostTx.wait();

    newBoost = await boostContract.getBoost(PROPOSAL_ID);

    expect(newBoost.id).to.equal(PROPOSAL_ID, "Boost id is not correct");
    expect(newBoost.token).to.equal(testToken.address, "Boost token is not correct");
    expect(newBoost.amountPerAccount).to.equal(ethers.BigNumber.from(AMOUNT_PER_ACC), "Boost amount per account is not correct");
    expect(newBoost.guard).to.equal(guard.address, "Boost guard is not correct");
    expect(newBoost.expires).to.equal(ethers.BigNumber.from(expire), "Boost expires is not correct");
    expect(newBoost.owner).to.equal(owner.address, "Boost owner is not correct");
  });

  it("Should show owner's allowance (50) and balance (100) for the created boost", async function () {
    const ownerBalance = await boostContract.ownerBalance(newBoost.id);
    expect(ownerBalance).to.deep.equal([
      ethers.BigNumber.from(50),
      ethers.BigNumber.from(100),
    ]);
  });

  it(`Should allow voter1 to claim ${AMOUNT_PER_ACC} tokens for voter1`, async function () {
    await canClaim(newBoost.id, voter1, [voter1], await getSigs([voter1], guard, newBoost.id), testToken, [
      AMOUNT_PER_ACC,
      AMOUNT_PER_ACC,
    ]);
  });

  it(`Should not allow voter1 to claim ${AMOUNT_PER_ACC} tokens for voter1 again`, async function () {
    await cantClaim(
      newBoost.id,
      voter1,
      [voter1],
      await getSigs([voter1], guard, newBoost.id),
      "Recipient already claimed"
    );
  });

  it(`Should allow voter1 to claim ${AMOUNT_PER_ACC} tokens for voter2 and voter3`, async function () {
    await canClaim(
      newBoost.id,
      voter1,
      [voter2, voter3],
      await getSigs([voter2, voter3], guard, newBoost.id),
      testToken,
      [0, AMOUNT_PER_ACC, AMOUNT_PER_ACC]
    );
  });

  it(`Should not allow nonVoter to claim ${AMOUNT_PER_ACC} tokens for nonVoter with signature of voter5`, async function () {
    await cantClaim(
      newBoost.id,
      nonVoter,
      [nonVoter],
      await getSigs([voter5], guard, newBoost.id),
      "Invalid signature"
    );
  });

  it(`Should allow nonVoter to claim ${AMOUNT_PER_ACC} tokens for voter4 with signature of voter 4`, async function () {
    await canClaim(
      newBoost.id,
      nonVoter,
      [voter4],
      await getSigs([voter4], guard, newBoost.id),
      testToken,
      [0, AMOUNT_PER_ACC, AMOUNT_PER_ACC]
    );
  });

  it(`Should not allow voter5 to claim ${AMOUNT_PER_ACC} tokens after boost has expired`, async function () {
    await network.provider.send("evm_increaseTime", [61]);
    await network.provider.send("evm_mine");
    await cantClaim(
      newBoost.id,
      voter5,
      [voter5],
      await getSigs([voter5], guard, newBoost.id),
      "Boost expired"
    );
  });

  it("Should have an allowance over 42 of owner's test tokens and owner should have a balance of 92", async function () {
    const ownerBalance = await boostContract.ownerBalance(newBoost.id);
    expect(ownerBalance).to.deep.equal([
      ethers.BigNumber.from(42),
      ethers.BigNumber.from(92),
    ]);
  });
});

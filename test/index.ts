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

  const proposalId = "0x1";
  const amountPerAccount = 2;
  const signatures: any[] = [];

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

  before(async function () {
    [owner, guard, voter1, voter2, voter3, voter4, voter5, nonVoter] =
      await ethers.getSigners();

    // deploy boost
    const Boost = await ethers.getContractFactory("Boost");
    boostContract = await Boost.deploy();
    await boostContract.deployed();

    // deploy test token (mints 1000000 to owner)
    const TestToken = await ethers.getContractFactory("TestToken");
    testToken = await TestToken.deploy();
    await testToken.deployed();

    // allow boost contract to spend test token on behalf of owner
    await testToken.connect(owner).approve(boostContract.address, 50);
  });

  it("Should create a boost as owner", async function () {
    // generate bytes32 id from string
    const id = ethers.utils.id(proposalId);

    const expire = (await ethers.provider.getBlock("latest")).timestamp + 60;

    const createBoostTx = await boostContract
      .connect(owner)
      .create(id, testToken.address, amountPerAccount, guard.address, expire);
    await createBoostTx.wait();

    newBoost = await boostContract.getBoost(id);

    expect(newBoost.id).to.equal(id);
  });

  it("Should have an allowance over 50 of owner's test tokens and owner should have a balance of 100", async function () {
    const ownerBalance = await boostContract.ownerBalance(newBoost.id);
    expect(ownerBalance).to.deep.equal([
      ethers.BigNumber.from(50),
      ethers.BigNumber.from(100),
    ]);
  });

  it(`Should generate signatures for voter1-5 but not for nonVoter`, async function () {
    // generate signatures from boost id and voter addresses
    for (const voter of [voter1, voter2, voter3, voter4, voter5]) {
      const message = ethers.utils.arrayify(
        ethers.utils.solidityKeccak256(
          ["bytes32", "address"],
          [newBoost.id, voter.address]
        )
      );
      const sig = await guard.signMessage(message);
      signatures.push(sig);
    }
  });

  it(`Should allow voter1 to claim ${amountPerAccount} tokens for voter1`, async function () {
    await canClaim(newBoost.id, voter1, [voter1], [signatures[0]], testToken, [
      amountPerAccount,
      amountPerAccount,
    ]);
  });

  it(`Should not allow voter1 to claim ${amountPerAccount} tokens for voter1 again`, async function () {
    await cantClaim(
      newBoost.id,
      voter1,
      [voter1],
      [signatures[0]],
      "Recipient already claimed"
    );
  });

  it(`Should allow voter1 to claim ${amountPerAccount} tokens for voter2 and voter3`, async function () {
    await canClaim(
      newBoost.id,
      voter1,
      [voter2, voter3],
      [signatures[1], signatures[2]],
      testToken,
      [0, amountPerAccount, amountPerAccount]
    );
  });

  it(`Should not allow nonVoter to claim ${amountPerAccount} tokens for nonVoter with signature of voter5`, async function () {
    await cantClaim(
      newBoost.id,
      nonVoter,
      [nonVoter],
      [signatures[4]],
      "Invalid signature"
    );
  });

  it(`Should allow nonVoter to claim ${amountPerAccount} tokens for voter4`, async function () {
    await canClaim(
      newBoost.id,
      nonVoter,
      [voter4],
      [signatures[3]],
      testToken,
      [0, amountPerAccount, amountPerAccount]
    );
  });

  it(`Should not allow voter5 to claim ${amountPerAccount} tokens after boost has expired`, async function () {
    await network.provider.send("evm_increaseTime", [61]);
    await network.provider.send("evm_mine");
    await cantClaim(
      newBoost.id,
      voter5,
      [voter5],
      [signatures[4]],
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

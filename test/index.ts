import { expect } from 'chai';
import { ethers } from "hardhat";

describe("Boost", function () {
  let owner: any;
  let guard: any;
  let voter1: any;
  let voter2: any;
  let voter3: any;
  let voter4: any;
  let nonVoter: any;
  let testToken: any;
  let boostContract: any;
  let newBoost: any;

  const proposalId = "0x1";
  const amountPerAccount = 2;
  const signatures: any[] = [];

  before(async function () {
    [ owner, guard, voter1, voter2, voter3, voter4, nonVoter ] = await ethers.getSigners();

    // deploy boost
    const Boost = await ethers.getContractFactory("Boost");
    boostContract = await Boost.deploy();
    await boostContract.deployed();

    // deploy test token (mints 1000000 to owner)
    const TestToken = await ethers.getContractFactory("TestToken");
    testToken = await TestToken.deploy();
    await testToken.deployed();

    // allow boost contract to spend test token on behalf of owner
    await testToken.approve(boostContract.address, 50);
  });

  it("Should create a boost as owner", async function () {
    // generate bytes32 id from string
    const id = ethers.utils.id(proposalId);

    const expire = (await ethers.provider.getBlock("latest")).timestamp + 10;

    const createBoostTx = await boostContract.create(
      id,
      testToken.address,
      amountPerAccount,
      guard.address,
      expire
    );
    await createBoostTx.wait();

    newBoost = await boostContract.getBoost(id);

    expect(newBoost.id).to.equal(id);
  });

  it("Should have an allowance over 50 of owner's test tokens and owner should have a balance of 100", async function () {
    const ownerBalance = await boostContract.ownerBalance(newBoost.id);
    expect(ownerBalance).to.deep.equal([ethers.BigNumber.from(50), ethers.BigNumber.from(100)]);
  });

  it(`Should generate signatures for voter1, voter2, voter3 and voter4 but not for nonVoter`, async function () {
    // generate signatures from boost id and voter addresses
    const message1 = ethers.utils.arrayify(ethers.utils.solidityKeccak256(
      ['bytes32', 'address'],
      [newBoost.id, voter1.address]
    ));
    const message2 = ethers.utils.arrayify(ethers.utils.solidityKeccak256(
      ['bytes32', 'address'],
      [newBoost.id, voter2.address]
    ));
    const message3 = ethers.utils.arrayify(ethers.utils.solidityKeccak256(
      ['bytes32', 'address'],
      [newBoost.id, voter3.address]
    ));
    const message4 = ethers.utils.arrayify(ethers.utils.solidityKeccak256(
      ['bytes32', 'address'],
      [newBoost.id, voter4.address]
    ));
    const sig1 = await guard.signMessage(message1);
    const sig2 = await guard.signMessage(message2);
    const sig3 = await guard.signMessage(message3);
    const sig4 = await guard.signMessage(message4);
    signatures.push(sig1, sig2, sig3, sig4);
  });

  it(`Should allow voter1 to claim ${amountPerAccount} tokens for voter1`, async function () {
    const claimTx = await boostContract.claim(newBoost.id, [voter1.address], [signatures[0]]);
    await claimTx.wait();

    const voter1Balance = await testToken.balanceOf(voter1.address);
    expect(voter1Balance).to.equal(ethers.BigNumber.from(amountPerAccount));
  });
  
  it(`Should not allow voter1 to claim ${amountPerAccount} tokens for voter1 again`, async function () {
    const claim = boostContract.claim(newBoost.id, [voter1.address], [signatures[0]]);
    await expect(claim).to.be.revertedWith('Recipient already claimed');
  });

  it(`Should allow voter1 to claim ${amountPerAccount} tokens for voter2 and voter3`, async function () {
    const claimTx = await boostContract.claim(newBoost.id, [voter2.address, voter3.address], [signatures[1], signatures[2]]);
    await claimTx.wait();

    const voter2Balance = await testToken.balanceOf(voter2.address);
    const voter3Balance = await testToken.balanceOf(voter3.address);
    expect(voter2Balance.add(voter3Balance)).to.equal(ethers.BigNumber.from(amountPerAccount * 2));
  });

  it(`Should not allow nonVoter to claim ${amountPerAccount} tokens for nonVoter`, async function () {
    const claim = boostContract.claim(newBoost.id, [nonVoter.address], [signatures[0]]);
    await expect(claim).to.be.revertedWith('Invalid signature');
  });
  
  it(`Should allow nonVoter to claim ${amountPerAccount} tokens for voter4`, async function () {
    const claimTx = await boostContract.claim(newBoost.id, [voter4.address], [signatures[3]]);
    await claimTx.wait();

    const voter4Balance = await testToken.balanceOf(voter4.address);
    expect(voter4Balance).to.equal(ethers.BigNumber.from(amountPerAccount));
  });
});

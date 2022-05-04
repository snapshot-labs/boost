import { expect } from "chai";
import { ethers, network } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

describe("Creating", function () {
  it(`is possible after allowing boost to move tokens`);
  it(`is not possible if deposit amount exceeds token allowance`);
  it(`is not possible if deposit amount exceeds token balance`);
  it(`is not possible if amount per account is more than deposit amount`);
  it(`is not possible if amount per account is 0`);
  it(`is not possible if deposit amount is 0`);
  it(`is not possible with the same boost id twice`);
});

describe("Depositing", function () {
  it(`is possible for existing boost`);
  it(`is not possible for non-existing boost`);
  it(`is only possible for boost owner`);
  it(`is not possible after boost expired`);
});

describe("Claiming", function () {
  it(`can be triggered by anyone with guard signature`);
  it(`is possible only once per signature`);
  it(`is not possible with invalid signature`);
  it(`is possible for multiple recipients at once`);
  it(`is not possible after boost expired`);
  it(`can not exceed boost balance`);
});

describe("Withdrawing", function () {
  it(`is possible after boost expired`);
  it(`is not possible before boost expired`);
  it(`is only possible for owner`);
});
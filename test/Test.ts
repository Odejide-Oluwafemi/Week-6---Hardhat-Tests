import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import hre from "hardhat";

describe("SaveEther", function() {
  async function deployContracts() {
    const [owner, otherAccount] = await hre.ethers.getSigners();

    const MyERC20 = await hre.ethers.getContractFactory("MyERC20");
    const SaveToken = await hre.ethers.getContractFactory("SaveToken");

    const NAME = "My Token";
    const SYMBOL = "MTK";
    const DECIMALS = 18;
    const TOTAL_SUPPLY = 100000000000000000000000000n;

    const token = await MyERC20.deploy(NAME, SYMBOL, DECIMALS, TOTAL_SUPPLY);
    const contract = await SaveToken.deploy(await token.getAddress());

    return { token, contract, owner, otherAccount };
  }

  describe("SaveToken", function() {
    it("Should have Token Address set", async function() {
      const { contract, token } = await loadFixture(deployContracts);

      expect(await contract.getTokenAddress()).to.be.equals(await token.getAddress());
    });
  });
});
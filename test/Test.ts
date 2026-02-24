import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import hre, { ethers } from "hardhat";

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

    it("Should deposit ETH by user", async function() {
      const { contract, otherAccount } = await loadFixture(deployContracts);
      
      const depositAmount = ethers.parseEther("1");
      await contract.connect(otherAccount).depositEth({ value: depositAmount });

      // Ensure Contract now has {depositAmount} balance
      expect(await ethers.provider.getBalance(contract)).to.equal(depositAmount);

      // Ensure that the User ETH balance in our contract record is correct as well
      expect(await contract.connect(otherAccount).checkUserEthBalanceInContract()).to.equal(depositAmount);
    });

    it("Should withdraw ETH by user", async function() {
      const { contract, otherAccount } = await loadFixture(deployContracts);
      
      // Deposit
      const depositAmount = ethers.parseEther("1");
      await contract.connect(otherAccount).depositEth({ value: depositAmount });
      
      // Withdraw
      await contract.connect(otherAccount).withdrawEth();
      expect(await ethers.provider.getBalance(contract)).to.equal(0);
      expect(await contract.connect(otherAccount).checkUserEthBalanceInContract()).to.equal(0);
    });

    it("Should deposit token by User", async function() {
      const { contract, token, otherAccount } = await loadFixture(deployContracts);

      // User buys token firstly from the token contract
      const ethPaid = ethers.parseEther("1");
      await token.connect(otherAccount).buyToken({ value: ethPaid});

      // Ensure User token balance is correctly updated
      const tokenQuantityBought = await token.getTokenQuantityForEth(ethPaid);
      const userTokenBalance = await token.connect(otherAccount).balanceOf(otherAccount.address);
      expect(userTokenBalance).to.equal(tokenQuantityBought);

      //
    });
  });
});
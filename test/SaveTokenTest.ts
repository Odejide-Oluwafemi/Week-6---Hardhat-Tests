import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import hre, { ethers } from "hardhat";

describe("All Tests", function () {
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

  describe("SaveToken", function () {
    it("Should have Token Address set", async function () {
      const { contract, token } = await loadFixture(deployContracts);

      expect(await contract.getTokenAddress()).to.be.equals(
        await token.getAddress(),
      );
    });

    it("Should deposit ETH by user", async function () {
      const { contract, otherAccount } = await loadFixture(deployContracts);

      const depositAmount = ethers.parseEther("1");
      await contract.connect(otherAccount).depositEth({ value: depositAmount });

      // Ensure Contract now has {depositAmount} balance
      expect(await ethers.provider.getBalance(contract)).to.equal(
        depositAmount,
      );

      // Ensure that the User ETH balance in our contract record is correct as well
      expect(
        await contract.connect(otherAccount).checkUserEthBalanceInContract(),
      ).to.equal(depositAmount);
    });

    it("Should withdraw ETH by user", async function () {
      const { contract, otherAccount } = await loadFixture(deployContracts);

      // Deposit
      const depositAmount = ethers.parseEther("1");
      await contract.connect(otherAccount).depositEth({ value: depositAmount });

      // Withdraw
      await contract.connect(otherAccount).withdrawEth();
      expect(await ethers.provider.getBalance(contract)).to.equal(0);
      expect(
        await contract.connect(otherAccount).checkUserEthBalanceInContract(),
      ).to.equal(0);
    });

    it("Should deposit token by User", async function () {
      const { contract, token, otherAccount } = await loadFixture(
        deployContracts,
      );

      // User buys token firstly from the token contract
      const ethPaid = ethers.parseEther("1");
      const tokenQuantityBought = await token.getTokenQuantityForEth(ethPaid);
      await token.connect(otherAccount).buyToken({ value: ethPaid });

      // Assert that user got the correct amount of Tokens
      const userInitialTokenBalance = await token.balanceOf(
        otherAccount.address,
      );
      expect(userInitialTokenBalance).to.be.equal(tokenQuantityBought);

      // User Approves contract to spend token
      const depositAmount = 1;
      await token
        .connect(otherAccount)
        .approve(await contract.getAddress(), depositAmount);
      expect(
        await token.allowance(
          otherAccount.address,
          await contract.getAddress(),
        ),
      ).to.equal(depositAmount); // Check Allowance is set properly

      // User can now deposit in our Contract
      const contractInitialTokenBalance =
        await contract.checkContractTokenBalance(); // Contracts' token balance before user token deposit
      await contract.connect(otherAccount).depositToken(depositAmount);

      // Checks
      const contractFinalTokenBalance =
        await contract.checkContractTokenBalance();
      const userFinalTokenBalance = await token
        .connect(otherAccount)
        .balanceOf(otherAccount.address);

      expect(userFinalTokenBalance).to.be.lessThan(userInitialTokenBalance); // that is, User now has a reduced balance
      expect(contractFinalTokenBalance).to.be.greaterThan(
        contractInitialTokenBalance,
      ); // contract now has more balance

      expect(
        await contract.connect(otherAccount).getUserDepositedTokenBalance(),
      ).to.equal(depositAmount);
    });

    it("Should withdraw token by user", async function () {
      const { token, contract, otherAccount } = await loadFixture(
        deployContracts,
      );

      // User Deposit Token
      // User buys token firstly from the token contract
      const ethPaid = ethers.parseEther("1");
      const tokenQuantityBought = await token.getTokenQuantityForEth(ethPaid);
      await token.connect(otherAccount).buyToken({ value: ethPaid });

      // Assert that user got the correct amount of Tokens
      const userInitialTokenBalance = await token.balanceOf(
        otherAccount.address,
      );
      expect(userInitialTokenBalance).to.be.equal(tokenQuantityBought);

      // User Approves contract to spend token
      const depositAmount = 1n;
      await token
        .connect(otherAccount)
        .approve(await contract.getAddress(), depositAmount);
      expect(
        await token.allowance(
          otherAccount.address,
          await contract.getAddress(),
        ),
      ).to.equal(depositAmount); // Check Allowance is set properly

      // User can now deposit in our Contract
      const contractInitialTokenBalance =
        await contract.checkContractTokenBalance(); // Contracts' token balance before user token deposit

      await contract.connect(otherAccount).depositToken(depositAmount);
      const userTokenBalanceAfterDeposit = await token
        .connect(otherAccount)
        .balanceOf(otherAccount.address);

      // User Withdraws
      await contract.connect(otherAccount).withdrawToken(depositAmount);

      // Checks
      const userFinalTokenBalance = await token
        .connect(otherAccount)
        .balanceOf(otherAccount.address);
      expect(userFinalTokenBalance).to.equals(
        userTokenBalanceAfterDeposit + depositAmount,
      );
    });
  });

  describe("School Management System Tests", async function () {
    it("Should check if the token address is correctly set", async function () {
      const { contract, token } = await loadFixture(deployContracts);
      expect(await contract.getTokenAddress()).to.equals(
        await token.getAddress(),
      );
    });
  });
});

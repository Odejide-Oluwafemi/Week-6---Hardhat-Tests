import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import hre, { ethers } from "hardhat";

describe("All Tests", function () {
  async function deployContracts() {
    const [owner, otherAccount] = await hre.ethers.getSigners();

    const MyERC20 = await hre.ethers.getContractFactory("MyERC20");
    const SaveToken = await hre.ethers.getContractFactory("SaveToken");
    const SchoolManagementSystem = await hre.ethers.getContractFactory("SchoolManagementSystem");

    const NAME = "My Token";
    const SYMBOL = "MTK";
    const DECIMALS = 18;
    const TOTAL_SUPPLY = 100000000000000000000000000n;

    const token = await MyERC20.connect(owner).deploy(NAME, SYMBOL, DECIMALS, TOTAL_SUPPLY);
    const saveTokenContract = await SaveToken.connect(owner).deploy(await token.getAddress());
    const schoolContract = await SchoolManagementSystem.connect(owner).deploy(await token.getAddress());

    return { token, saveTokenContract, schoolContract, owner, otherAccount, NAME, SYMBOL, DECIMALS, TOTAL_SUPPLY };
  }

  describe("MyERC20", function() {
    it("Should have constructor details set", async function() {
      const {NAME, SYMBOL, DECIMALS, TOTAL_SUPPLY, token} = await loadFixture(deployContracts);

      expect(await token.name()).to.equals(NAME);
      expect(await token.symbol()).to.equals(SYMBOL);
      expect(await token.totalSupply()).to.equals(TOTAL_SUPPLY);
      expect(await token.decimals()).to.equals(DECIMALS);

      expect(await token.balanceOf(await token.getAddress())).to.equals(TOTAL_SUPPLY);
    });

    it("Should allow Users to Buy Tokens", async function() {
      const { owner, token } = await loadFixture(deployContracts);

      const purchaseEthAmount = ethers.parseEther("1");
      await token.connect(owner).buyToken({value: purchaseEthAmount});

      expect(await token.balanceOf(await owner.getAddress())).to.equals(await token.getTokenQuantityForEth(purchaseEthAmount));
    });

    it("Should allow owner withdraw ETH funds in contract", async function() {
      // User Buy Token
      const { owner, otherAccount, token } = await loadFixture(deployContracts);

      const purchaseEthAmount = ethers.parseEther("1");
      await token.connect(otherAccount).buyToken({value: purchaseEthAmount});

      expect(await token.balanceOf(await otherAccount.getAddress())).to.equals(await token.getTokenQuantityForEth(purchaseEthAmount));

      // Check ETH balance of contract
      expect(await hre.ethers.provider.getBalance(await token.getAddress())).to.equals(purchaseEthAmount);

      // Owner withdraws
      const ownerBalanceBeforeWithdrawal = await hre.ethers.provider.getBalance(owner.address);
      await token.connect(owner).withdraw();
      const ownerBalanceAfterWithdrawal = await hre.ethers.provider.getBalance(owner.address);
      expect(ownerBalanceAfterWithdrawal).to.be.greaterThan(ownerBalanceBeforeWithdrawal);
    });

     it("Should revert when an unauthorized account tries to withdraw", async function() {
      const { otherAccount, token } = await loadFixture(deployContracts);
      await expect(token.connect(otherAccount).withdraw()).to.be.revertedWith("Only Owner can call this function");
    });

    it("Should revert when transferFrom is called with Insufficient Allowance from spender", async function() {
      const { saveTokenContract, owner, otherAccount, token } = await loadFixture(deployContracts);
      await expect(token.connect(owner).transferFrom(await saveTokenContract.getAddress(), otherAccount.address, 1n)).to.be.revertedWithCustomError(
        token, "MyERC20__InsufficientAllowance"
      );
    });
  });

  describe("SaveToken", function () {
    it("Should have Token Address set", async function () {
      const { saveTokenContract, token } = await loadFixture(deployContracts);

      expect(await saveTokenContract.getTokenAddress()).to.be.equals(
        await token.getAddress(),
      );
    });

    it("Should deposit ETH by user", async function () {
      const { saveTokenContract, otherAccount } = await loadFixture(deployContracts);

      const depositAmount = ethers.parseEther("1");
      await saveTokenContract.connect(otherAccount).depositEth({ value: depositAmount });

      // Ensure Contract now has {depositAmount} balance
      expect(await ethers.provider.getBalance(saveTokenContract)).to.equal(
        depositAmount,
      );

      // Ensure that the User ETH balance in our contract record is correct as well
      expect(
        await saveTokenContract.connect(otherAccount).checkUserEthBalanceInContract(),
      ).to.equal(depositAmount);
    });

    it("Should withdraw ETH by user", async function () {
      const { saveTokenContract, otherAccount } = await loadFixture(deployContracts);

      // Deposit
      const depositAmount = ethers.parseEther("1");
      await saveTokenContract.connect(otherAccount).depositEth({ value: depositAmount });

      // Withdraw
      await saveTokenContract.connect(otherAccount).withdrawEth();
      expect(await ethers.provider.getBalance(saveTokenContract)).to.equal(0);
      expect(
        await saveTokenContract.connect(otherAccount).checkUserEthBalanceInContract(),
      ).to.equal(0);
    });

    it("Should deposit token by User", async function () {
      const { saveTokenContract, token, otherAccount } = await loadFixture(
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
        .approve(await saveTokenContract.getAddress(), depositAmount);
      expect(
        await token.allowance(
          otherAccount.address,
          await saveTokenContract.getAddress(),
        ),
      ).to.equal(depositAmount); // Check Allowance is set properly

      // User can now deposit in our Contract
      const contractInitialTokenBalance =
        await saveTokenContract.checkContractTokenBalance(); // Contracts' token balance before user token deposit
      await saveTokenContract.connect(otherAccount).depositToken(depositAmount);

      // Checks
      const contractFinalTokenBalance =
        await saveTokenContract.checkContractTokenBalance();
      const userFinalTokenBalance = await token
        .connect(otherAccount)
        .balanceOf(otherAccount.address);

      expect(userFinalTokenBalance).to.be.lessThan(userInitialTokenBalance); // that is, User now has a reduced balance
      expect(contractFinalTokenBalance).to.be.greaterThan(
        contractInitialTokenBalance,
      ); // contract now has more balance

      expect(
        await saveTokenContract.connect(otherAccount).getUserDepositedTokenBalance(),
      ).to.equal(depositAmount);
    });

    it("Should withdraw token by user", async function () {
      const { token, saveTokenContract, otherAccount } = await loadFixture(
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
        .approve(await saveTokenContract.getAddress(), depositAmount);
      expect(
        await token.allowance(
          otherAccount.address,
          await saveTokenContract.getAddress(),
        ),
      ).to.equal(depositAmount); // Check Allowance is set properly

      // User can now deposit in our Contract
      const contractInitialTokenBalance =
        await saveTokenContract.checkContractTokenBalance(); // Contracts' token balance before user token deposit

      await saveTokenContract.connect(otherAccount).depositToken(depositAmount);
      const userTokenBalanceAfterDeposit = await token
        .connect(otherAccount)
        .balanceOf(otherAccount.address);

      // User Withdraws
      await saveTokenContract.connect(otherAccount).withdrawToken(depositAmount);

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
    it("Should check if the token and owner addresses are correctly set", async function () {
      const { saveTokenContract, schoolContract, token, owner } = await loadFixture(deployContracts);

      expect(await saveTokenContract.getTokenAddress()).to.equals(
        await token.getAddress(),
      );

      expect(await schoolContract.getOwner()).to.equals(await owner.getAddress());
    });

    it("Can register student", async function() {

    });
  });
});

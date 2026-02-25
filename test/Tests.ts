import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { BigNumberish, parseEther } from "ethers";
import hre, { ethers } from "hardhat";

describe("All Tests", function () {
  async function deployContracts() {
    const [owner, otherAccount, account3, account4] =
      await hre.ethers.getSigners();

    const MyERC20 = await hre.ethers.getContractFactory("MyERC20");
    const SaveToken = await hre.ethers.getContractFactory("SaveToken");
    const SchoolManagementSystem = await hre.ethers.getContractFactory(
      "SchoolManagementSystem",
    );
    const PropertyManagementSystem = await hre.ethers.getContractFactory(
      "PropertyManagement",
    );
    const MultiSigWallet = await ethers.getContractFactory("MultiSigWallet");

    const NAME = "My Token";
    const SYMBOL = "MTK";
    const DECIMALS = 18;
    const TOTAL_SUPPLY = 100000000000000000000000000n;

    // Deployment
    const token = await MyERC20.connect(owner).deploy(
      NAME,
      SYMBOL,
      DECIMALS,
      TOTAL_SUPPLY,
    );
    const saveTokenContract = await SaveToken.connect(owner).deploy(
      await token.getAddress(),
    );
    const schoolContract = await SchoolManagementSystem.connect(owner).deploy(
      await token.getAddress(),
    );
    const propertyContract = await PropertyManagementSystem.connect(
      owner,
    ).deploy(await token.getAddress());
    const multiSigContract = await MultiSigWallet.deploy(
      owner.address,
      otherAccount.address,
      account3.address,
    );

    return {
      token,
      saveTokenContract,
      schoolContract,
      propertyContract,
      multiSigContract,
      owner,
      otherAccount,
      account3,
      account4,
      NAME,
      SYMBOL,
      DECIMALS,
      TOTAL_SUPPLY,
    };
  }

  describe("MyERC20", function () {
    it("Should have constructor details set", async function () {
      const { NAME, SYMBOL, DECIMALS, TOTAL_SUPPLY, token } = await loadFixture(
        deployContracts,
      );

      expect(await token.name()).to.equals(NAME);
      expect(await token.symbol()).to.equals(SYMBOL);
      expect(await token.totalSupply()).to.equals(TOTAL_SUPPLY);
      expect(await token.decimals()).to.equals(DECIMALS);

      expect(await token.balanceOf(await token.getAddress())).to.equals(
        TOTAL_SUPPLY,
      );
    });

    it("Should allow Users to Buy Tokens", async function () {
      const { owner, token } = await loadFixture(deployContracts);

      const purchaseEthAmount = ethers.parseEther("1");
      await token.connect(owner).buyToken({ value: purchaseEthAmount });

      expect(await token.balanceOf(await owner.getAddress())).to.equals(
        await token.getTokenQuantityForEth(purchaseEthAmount),
      );
    });

    it("Should allow owner withdraw ETH funds in contract", async function () {
      // User Buy Token
      const { owner, otherAccount, token } = await loadFixture(deployContracts);

      const purchaseEthAmount = ethers.parseEther("1");
      await token.connect(otherAccount).buyToken({ value: purchaseEthAmount });

      expect(await token.balanceOf(await otherAccount.getAddress())).to.equals(
        await token.getTokenQuantityForEth(purchaseEthAmount),
      );

      // Check ETH balance of contract
      expect(
        await hre.ethers.provider.getBalance(await token.getAddress()),
      ).to.equals(purchaseEthAmount);

      // Owner withdraws
      const ownerBalanceBeforeWithdrawal = await hre.ethers.provider.getBalance(
        owner.address,
      );
      await token.connect(owner).withdraw();
      const ownerBalanceAfterWithdrawal = await hre.ethers.provider.getBalance(
        owner.address,
      );
      expect(ownerBalanceAfterWithdrawal).to.be.greaterThan(
        ownerBalanceBeforeWithdrawal,
      );
    });

    it("Should revert when an unauthorized account tries to withdraw", async function () {
      const { otherAccount, token } = await loadFixture(deployContracts);
      await expect(token.connect(otherAccount).withdraw()).to.be.revertedWith(
        "Only Owner can call this function",
      );
    });

    it("Should revert when transferFrom is called with Insufficient Allowance from spender", async function () {
      const { saveTokenContract, owner, otherAccount, token } =
        await loadFixture(deployContracts);
      await expect(
        token
          .connect(owner)
          .transferFrom(
            await saveTokenContract.getAddress(),
            otherAccount.address,
            1n,
          ),
      ).to.be.revertedWithCustomError(token, "MyERC20__InsufficientAllowance");
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
      const { saveTokenContract, otherAccount } = await loadFixture(
        deployContracts,
      );

      const depositAmount = ethers.parseEther("1");
      await saveTokenContract
        .connect(otherAccount)
        .depositEth({ value: depositAmount });

      // Ensure Contract now has {depositAmount} balance
      expect(await ethers.provider.getBalance(saveTokenContract)).to.equal(
        depositAmount,
      );

      // Ensure that the User ETH balance in our contract record is correct as well
      expect(
        await saveTokenContract
          .connect(otherAccount)
          .checkUserEthBalanceInContract(),
      ).to.equal(depositAmount);
    });

    it("Should withdraw ETH by user", async function () {
      const { saveTokenContract, otherAccount } = await loadFixture(
        deployContracts,
      );

      // Deposit
      const depositAmount = ethers.parseEther("1");
      await saveTokenContract
        .connect(otherAccount)
        .depositEth({ value: depositAmount });

      // Withdraw
      await saveTokenContract.connect(otherAccount).withdrawEth();
      expect(await ethers.provider.getBalance(saveTokenContract)).to.equal(0);
      expect(
        await saveTokenContract
          .connect(otherAccount)
          .checkUserEthBalanceInContract(),
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
        await saveTokenContract
          .connect(otherAccount)
          .getUserDepositedTokenBalance(),
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
      await saveTokenContract
        .connect(otherAccount)
        .withdrawToken(depositAmount);

      // Checks
      const userFinalTokenBalance = await token
        .connect(otherAccount)
        .balanceOf(otherAccount.address);
      expect(userFinalTokenBalance).to.equals(
        userTokenBalanceAfterDeposit + depositAmount,
      );
    });
  });

  describe("School Management System Tests", function () {
    it("Should check if the token and owner addresses are correctly set", async function () {
      const { saveTokenContract, schoolContract, token, owner } =
        await loadFixture(deployContracts);

      expect(await saveTokenContract.getTokenAddress()).to.equals(
        await token.getAddress(),
      );

      expect(await schoolContract.getOwner()).to.equals(
        await owner.getAddress(),
      );
    });

    it("Can register student", async function () {
      const { schoolContract, owner, token } = await loadFixture(
        deployContracts,
      );

      const name = "Name";
      const age = 12n;
      const grade = 0n;
      const fee = await schoolContract.getStkPriceForGrade(grade);

      // Check Balance
      if ((await token.balanceOf(owner.address)) < fee) {
        await token.connect(owner).buyToken({ value: ethers.parseEther("1") });
      }

      // Give Allowance
      await token
        .connect(owner)
        .approve(await schoolContract.getAddress(), fee);

      // Register
      await schoolContract.connect(owner).registerStudent(name, age, grade);

      expect(
        (await schoolContract.getStudentDetail(owner.address)).name,
      ).to.equals(name);
      expect(
        (await schoolContract.getStudentDetail(owner.address)).age,
      ).to.equals(age);
      expect(
        (await schoolContract.getStudentDetail(owner.address)).grade,
      ).to.equals(grade);
      expect(
        (await schoolContract.getStudentDetail(owner.address)).suspended,
      ).to.equals(false);
    });

    it("Can register staff", async function () {
      const { schoolContract, owner } = await loadFixture(deployContracts);

      const name = "Staff";
      const age = 12n;

      await schoolContract.registerStaff(name, age);

      expect(
        (await schoolContract.getStaffDetail(owner.address)).name,
      ).to.equals(name);
      expect(
        (await schoolContract.getStaffDetail(owner.address)).age,
      ).to.equals(age);
    });

    it("Pays a single staff and emits Event", async function () {
      const { schoolContract, owner, otherAccount, token } = await loadFixture(
        deployContracts,
      );

      // Register a student first so we'll have money to pay staff
      const grade = 0n;
      const fee = await schoolContract.getStkPriceForGrade(grade);

      // Check Balance
      if ((await token.balanceOf(owner.address)) < fee) {
        await token.connect(owner).buyToken({ value: ethers.parseEther("1") });
      }

      // Give Allowance
      await token
        .connect(owner)
        .approve(await schoolContract.getAddress(), fee);

      // Register Student
      await schoolContract.connect(owner).registerStudent("name", 12n, grade);

      // Register Staff
      await schoolContract.connect(otherAccount).registerStaff("Name", 12n);

      // Pay Staff and Expect to Emit Event
      expect(await schoolContract.connect(owner).payStaff(0n))
        .to.emit(schoolContract, "StaffPaid")
        .withArgs(await schoolContract.getStaffDetail(otherAccount.address));

      // Check balance of staff to be equal to his salary
      expect(await token.balanceOf(otherAccount.address)).to.equals(
        (await schoolContract.getStaffDetail(otherAccount.address)).salary,
      );
    });

    it("Suspends Staff and emits Event", async function () {
      const { owner, otherAccount, schoolContract } = await loadFixture(
        deployContracts,
      );
      await schoolContract.connect(otherAccount).registerStaff("Name", 12n);

      expect(await schoolContract.suspendStaff(otherAccount.address))
        .to.emit(schoolContract, "StaffSuspended")
        .withArgs(await schoolContract.getStaffDetail(otherAccount.address));

      expect(
        (await schoolContract.getStaffDetail(otherAccount.address)).suspended,
      ).to.be.equals(true);
    });

    it("Suspends Student and emits Event", async function () {
      const { schoolContract, owner, token } = await loadFixture(
        deployContracts,
      );

      // Register Student First
      const name = "Name";
      const age = 12n;
      const grade = 0n;
      const fee = await schoolContract.getStkPriceForGrade(grade);

      // Check Balance
      if ((await token.balanceOf(owner.address)) < fee) {
        await token.connect(owner).buyToken({ value: ethers.parseEther("1") });
      }

      // Give Allowance
      await token
        .connect(owner)
        .approve(await schoolContract.getAddress(), fee);

      // Register
      await schoolContract.connect(owner).registerStudent(name, age, grade);

      // Suspend
      expect(await schoolContract.suspendStudent(owner.address))
        .to.emit(schoolContract, "StudentSuspended")
        .withArgs(await schoolContract.getStudentDetail(owner.address));
    });

    it("Pays all staffs", async function () {
      const { schoolContract, owner, otherAccount, token } = await loadFixture(
        deployContracts,
      );

      // Register a student first so we'll have money to pay staff
      const grade = 3n;
      const fee = await schoolContract.getStkPriceForGrade(grade);

      // Check Balance
      if ((await token.balanceOf(owner.address)) < fee) {
        await token.connect(owner).buyToken({ value: ethers.parseEther("2") });
      }

      // Give Allowance
      await token
        .connect(owner)
        .approve(await schoolContract.getAddress(), fee);

      // Register Student
      await schoolContract.connect(owner).registerStudent("name", 12n, grade);
      // Register Staffs
      const staff1 = otherAccount;
      const [, , staff2] = await hre.ethers.getSigners();

      await schoolContract.connect(staff1).registerStaff("Name", 12n);
      await schoolContract.connect(staff2).registerStaff("Name2", 16n);

      // Pay Staff and Expect to Emit Event
      await schoolContract.connect(owner).payAllStaffs();

      // Check balance of staff to be equal to his salary
      expect(await token.balanceOf(staff1.address)).to.be.equals(
        (await schoolContract.getStaffDetail(staff1.address)).salary,
      );
      expect(await token.balanceOf(staff2.address)).to.equals(
        (await schoolContract.getStaffDetail(staff2.address)).salary,
      );
    });
  });

  describe("Property Management Tests", function () {
    it("Ensures token address is set properly", async function () {
      const { propertyContract, token } = await loadFixture(deployContracts);
      expect(await propertyContract.getTokenAddress()).to.be.equals(
        await token.getAddress(),
      );
    });

    it("Lists a new property and emits Event", async function () {
      const { propertyContract, token, owner } = await loadFixture(
        deployContracts,
      );

      // Buy Token
      await token.connect(owner).buyToken({ value: parseEther("1") });

      // Approve Contract
      const listingPrice = 1000n;
      await token
        .connect(owner)
        .approve(await propertyContract.getAddress(), listingPrice);

      // List
      expect(
        await propertyContract
          .connect(owner)
          .listNewProperty("Property Name", listingPrice),
      ).to.emit(propertyContract, "PropertyListed");
      expect((await propertyContract.getAllProperties()).length).to.be.equals(
        1,
      );
    });

    it("Delists property and emit Event", async function () {
      const { propertyContract, token, owner } = await loadFixture(
        deployContracts,
      );

      // Buy Token
      await token.connect(owner).buyToken({ value: parseEther("1") });

      // Approve Contract
      const listingPrice = 1000n;
      await token
        .connect(owner)
        .approve(await propertyContract.getAddress(), listingPrice);

      // List
      expect(
        await propertyContract
          .connect(owner)
          .listNewProperty("Property Name", listingPrice),
      ).to.emit(propertyContract, "PropertyListed");
      expect((await propertyContract.getAllProperties()).length).to.be.equals(
        1,
      );

      // Delist
      const propertyId = (await propertyContract.getAllProperties())[0].id;
      expect(
        await propertyContract.connect(owner).delistProperty(propertyId),
      ).to.emit(propertyContract, "PropertyDelisted");
      expect((await propertyContract.getPropertyById(propertyId)).id).to.equals(
        0,
      );
    });

    it("Should buy property and emit Event", async function () {
      const { propertyContract, token, owner, otherAccount } =
        await loadFixture(deployContracts);

      // Buy Token
      await token.connect(owner).buyToken({ value: parseEther("1") });

      // Approve Contract
      const listingPrice = 1000n;
      await token
        .connect(owner)
        .approve(await propertyContract.getAddress(), listingPrice);

      // List
      expect(
        await propertyContract
          .connect(owner)
          .listNewProperty("Property Name", listingPrice),
      ).to.emit(propertyContract, "PropertyListed");
      expect((await propertyContract.getAllProperties()).length).to.be.equals(
        1,
      );

      // Set Property For Sale
      await propertyContract
        .connect(owner)
        .setPropertyForSale(
          (
            await propertyContract.getAllProperties()
          )[0].id,
          true,
        );

      // otherAccount buys Token and approves
      await token
        .connect(otherAccount)
        .buyToken({ value: ethers.parseEther("2") });
      await token
        .connect(otherAccount)
        .approve(await propertyContract.getAddress(), listingPrice * 2n);

      // otherAccount Purchases Property
      expect(
        await propertyContract
          .connect(otherAccount)
          .buyProperty((await propertyContract.getAllProperties())[0].id),
      )
        .to.emit(propertyContract, "PropertyPurchased")
        .withArgs(
          owner,
          otherAccount,
          (await propertyContract.getAllProperties())[0].id,
          listingPrice,
        );

      expect((await propertyContract.getAllProperties())[0].owner).to.be.equals(
        otherAccount.address,
      );
    });

    it("Should revert when buying a property that is not for sale", async function () {
      const { propertyContract, token, owner, otherAccount } =
        await loadFixture(deployContracts);

      // Buy Token
      await token.connect(owner).buyToken({ value: parseEther("1") });

      // Approve Contract
      const listingPrice = 1000n;
      await token
        .connect(owner)
        .approve(await propertyContract.getAddress(), listingPrice);

      // List
      expect(
        await propertyContract
          .connect(owner)
          .listNewProperty("Property Name", listingPrice),
      ).to.emit(propertyContract, "PropertyListed");
      expect((await propertyContract.getAllProperties()).length).to.be.equals(
        1,
      );

      // otherAccount buys Token and approves
      await token
        .connect(otherAccount)
        .buyToken({ value: ethers.parseEther("2") });

      await token
        .connect(otherAccount)
        .approve(await propertyContract.getAddress(), listingPrice * 2n);

      // otherAccount Purchases Property
      await expect(
        propertyContract
          .connect(otherAccount)
          .buyProperty((await propertyContract.getAllProperties())[0].id + 1n),
      ).to.be.revertedWithCustomError(
        propertyContract,
        "Property__ThisPropertyIsNotListedForSale",
      );

      expect((await propertyContract.getAllProperties())[0].owner).to.be.equals(
        owner.address,
      );
    });
  });

  describe("MultiSig Wallet Tests", () => {
    it("Sets Signer Addresses", async function () {
      const { multiSigContract, owner, otherAccount, account3 } =
        await loadFixture(deployContracts);

      expect(await multiSigContract.signers(0)).to.equals(owner);
      expect(await multiSigContract.signers(1)).to.equals(otherAccount);
      expect(await multiSigContract.signers(2)).to.equals(account3);
    });
  });
});

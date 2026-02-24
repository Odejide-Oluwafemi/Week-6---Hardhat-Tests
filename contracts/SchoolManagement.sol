// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.3;

import {MyERC20} from "contracts/MyERC20.sol";

contract SchoolManagementSystem {
    /*
        Create a School management system where people can:

        - Register students & Employ Staffs.
        - Pay School fees on registration.
        - Pay staffs also.
        - Get the students and their details.
        - Get all Staffs.
        - Pricing is based on grade / levels from 100 - 400 level.
        - Payment status can be updated once the payment is made which should include the timestamp.

        ========================================================================================================================
        =================================================== Added Task =========================================================
        - Remove a registered student
        - Suspend Staff
    */

    // Errors
    error InsufficientTokenBalanceForRegistration();
    error StaffSalaryPaymentFailed(Staff staff);
    error OnlyOwnerCanCallThisFunction();
    error SchoolHasInsufficientFundsToPayStaffs();
    error Assignment__YouNeedToApproveFirst();
    error NotARegisteredStudent();
    error NotARegisteredStaff();

    // Enums
    enum PaymentStatus {
        Paid,
        Not_Paid
    }

    enum Grade {
        Level_100,
        Level_200,
        Level_300,
        Level_400
    }

    // Structs
    struct Student {
        string name;
        uint8 age;
        Grade grade;
        PaymentStatus paymentStatus;
        uint paymentTime;
        bool suspended;
    }

    struct Staff {
        address walletAddress;
        string name;
        uint8 age;
        uint salary;
        uint timeLastPaid;
        bool suspended;
    }

    // Events
    event StudentRegistered(
        address indexed studentAddress,
        Student studentDetail
    );
    
    event StudentSuspended(Student indexed student);

    event StaffRegistered(address indexed staffAddress, Staff staffDetail);

    event StaffPaid(Staff indexed staffDetails);

    event StaffSuspended(Staff indexed staff);

    // State Variables
    address immutable owner;
    MyERC20 immutable token;

    uint256 public constant BASE_REGISTRATION_FEE = 500;
    uint256 public constant BASE_STAFF_SALARY = 300; // 300 STK token (equivalent to 0.3 ETH based on 0.001 ETH/STK price)

    Student[] private allStudents;
    Staff[] private allStaffs;

    mapping(address studentAddress => Student studentDetail)
        private studentDetailFromAddress;
    
    mapping(address staffAddress => Staff staffDetail)
        private staffDetailFromAddress;

    constructor(MyERC20 _token) {
        owner = msg.sender;
        token = _token;
    }

    // Modifiers
    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwnerCanCallThisFunction();
        _;
    }

    // Write Functions
    function registerStudent(
        string memory _name,
        uint8 _age,
        Grade _grade
    ) public {
        uint registrationPrice = getStkPriceForGrade(_grade);

        if (token.allowance(msg.sender, address(this)) < registrationPrice) revert Assignment__YouNeedToApproveFirst();

        if (token.balanceOf(msg.sender) < registrationPrice)
            revert InsufficientTokenBalanceForRegistration();

        
        token.transferFrom(msg.sender, address(this), registrationPrice);

        Student memory newStudent = Student({
            name: _name,
            age: _age,
            grade: _grade,
            paymentStatus: PaymentStatus.Paid,
            paymentTime: block.timestamp,
            suspended: false
        });

        allStudents.push(newStudent);
        studentDetailFromAddress[msg.sender] = newStudent;

        emit StudentRegistered(msg.sender, newStudent);
    }

    function getStudentDetail(
        address studentAddress
    ) public view returns (Student memory) {
        return
            studentDetailFromAddress[
                studentAddress == address(0) ? msg.sender : studentAddress
            ];
    }

    function getStaffDetail(
        address staffAddress
    ) public view returns (Staff memory) {
        return
            staffDetailFromAddress[
                staffAddress == address(0) ? msg.sender : staffAddress
            ];
    }

    function registerStaff(string memory _name, uint8 _age) public {
        Staff memory newStaff = Staff({
            walletAddress: msg.sender,
            name: _name,
            age: _age,
            salary: BASE_STAFF_SALARY,
            timeLastPaid: 0,
            suspended: false
        });

        allStaffs.push(newStaff);
        staffDetailFromAddress[msg.sender] = newStaff;

        emit StaffRegistered(msg.sender, newStaff);
    }

    function payAllStaffs() public onlyOwner {
        for (uint i; i < allStaffs.length; i++) {
            payStaff(i);
        }
    }

    function payStaff(uint index) public onlyOwner {
        Staff memory staffDetails = allStaffs[index];

        if (!staffDetails.suspended) {
            allStaffs[index].timeLastPaid = block.timestamp;

            bool success = token.transfer(staffDetails.walletAddress, staffDetails.salary);

            if (!success) revert SchoolHasInsufficientFundsToPayStaffs();

            emit StaffPaid(allStaffs[index]);
        }
    }

    function suspendStudent(address studentAddress) public onlyOwner {
        if (studentDetailFromAddress[studentAddress].paymentTime == 0) revert NotARegisteredStudent();

        Student storage student = studentDetailFromAddress[studentAddress];
        student.suspended = true;

        emit StudentSuspended(student);
    }

    function suspendStaff(address staffAddress) public onlyOwner {
        if (staffDetailFromAddress[staffAddress].walletAddress == address(0)) revert NotARegisteredStaff();

        Staff storage staff = staffDetailFromAddress[staffAddress];
        staff.suspended = true;

        emit StaffSuspended(staff);
    }

    // Read Functions
    function getSchoolTokenBalance() external view returns (uint) {
        return token.balanceOf(address(this));
    }

    function getUserTokenBalance() public view returns (uint) {
        return token.balanceOf(msg.sender);
    }

    function getStkPriceForGrade(Grade grade) public pure returns (uint) {
        return BASE_REGISTRATION_FEE * (uint(grade) + 1);
    }

    function getTokenAddress() external view returns(address) {
        return address(token);
    }

    /*
        Create a School management system where people can:

        - Register students & Employ Staffs.
        - Pay School fees on registration.
        - Pay staffs also.
        - Get the students and their details.
        - Get all Staffs.
        - Pricing is based on grade / levels from 100 - 400 level.
        - Payment status can be updated once the payment is made which should include the timestamp.

        ========================================================================================================================
        =================================================== Added Task =========================================================
        - Remove a registered student
        - Suspend Staff
    */
}

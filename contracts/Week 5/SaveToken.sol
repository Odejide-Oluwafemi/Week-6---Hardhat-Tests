// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.3;

import {MyERC20} from "contracts/MyERC20.sol";

contract SaveToken {
    // Errors
    error FailedToDepositEth();
    error EthWithdrawFailed();
    error TokenWithdrawFailed();
    error InsufficientTokenFunds();
    error TryingToWithdrawUnavailableToken();
    error TokenWithdrawalFailed();
    error NotAllowed();
    error CannotWithdrawZeroBalance();
    error CannotDepositZeroAmount();
    error TokenDepositFailed();
    error Classwork__YouNeedToApproveFirst();

    MyERC20 immutable token;
    string constant NAME = "MyToken";
    string constant SYMBOL = "MYT";
    uint8 constant DECIMALS = 18;
    uint constant TOTAL_SUPPLY = 1000;

    mapping(address user => uint ethBalance) private ethBalance;
    mapping(address user => uint tokenBalance)
        private userDepositedTokenBalance;

    constructor(MyERC20 _token) {
        token = _token;
    }

    function getUserTokenBalance() public view returns (uint) {
        return token.balanceOf(msg.sender);
    }

    function getUserDepositedTokenBalance() public view returns (uint) {
        return userDepositedTokenBalance[msg.sender];
    }

    function checkUserWalletBalance() public view returns (uint) {
        return msg.sender.balance;
    }

    function checkUserEthBalanceInContract() public view returns (uint) {
        return ethBalance[msg.sender];
    }

    function depositToken(uint amount) public {
        if (amount == 0) revert CannotDepositZeroAmount();
        if (token.allowance(msg.sender, address(this)) < amount) revert Classwork__YouNeedToApproveFirst();

        bool success = token.transferFrom(msg.sender, address(this), amount);

        if (!success) revert TokenDepositFailed();

        userDepositedTokenBalance[msg.sender] += amount;
    }

    function depositEth() public payable {
        if (msg.value == 0) revert CannotDepositZeroAmount();
        ethBalance[msg.sender] += msg.value;
    }

    function checkContractTokenBalance() public view returns (uint) {
        return token.balanceOf(address(this));
    }

    function withdrawEth() public {
        uint balance = ethBalance[msg.sender];
        if (balance == 0) revert CannotWithdrawZeroBalance();

        (bool success, ) = payable(msg.sender).call{value: balance}("");
        ethBalance[msg.sender] -= balance;

        if (!success) revert EthWithdrawFailed();
    }

    function withdrawToken(uint amount) public {
        if (amount > userDepositedTokenBalance[msg.sender])
            revert TryingToWithdrawUnavailableToken();

        userDepositedTokenBalance[msg.sender] -= amount;
        bool success = token.transfer(msg.sender, amount);
        if (!success) revert TokenWithdrawalFailed();
    }

    function getTokenAddress() external view returns(address) {
        return address(token);
    }

    receive() external payable {
        depositEth();
    }
}
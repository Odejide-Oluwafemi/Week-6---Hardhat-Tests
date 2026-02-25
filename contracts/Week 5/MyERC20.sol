// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.3;

import {IMyERC20} from "contracts/Week 5/IMyERC20.sol";

contract MyERC20 is IMyERC20 {
    // Errors
    error MyERC20__AddressZeroError();
    error MyERC20__InsufficientFunds();
    error MyERC20__InsufficientAllowance();
    error MyERC20__ThisAmountOfNewTokenCannotBePurchased();

    uint256 public constant ETH_TO_TOKEN_PRICE = 0.001 ether; // this means that 0.001 ETH == 1 unit of Token, so 1 ETH will be equal to 1000 token
    string private NAME;
    string private SYMBOL;
    uint8 private DECIMALS;
    uint256 private TOTAL_SUPPLY;
    address public immutable OWNER;

    mapping(address owner => uint256 amount) _balances;
    mapping(address owner => mapping(address spender => uint256 amount)) _allowances;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _totalSupply
    ) {
        NAME = _name;
        SYMBOL = _symbol;
        DECIMALS = _decimals;
        TOTAL_SUPPLY = _totalSupply;
        _balances[address(this)] = _totalSupply;
        OWNER = msg.sender;
    }

    function buyToken() external payable returns (bool) {
        uint amountBought = getTokenQuantityForEth(msg.value);

        if (balanceOf(address(this)) < amountBought)
            revert MyERC20__ThisAmountOfNewTokenCannotBePurchased();

        _balances[address(this)] -= amountBought;
        _balances[msg.sender] += amountBought;

        emit Transfer(address(this), msg.sender, amountBought);

        return true;
    }

    modifier onlyOwner() {
        require(msg.sender == OWNER, "Only Owner can call this function");
        _;
    }

    function withdraw() external onlyOwner {
        (bool success, ) = payable(OWNER).call{value: address(this).balance}(
            ""
        );
        require(success);
    }

    function getTokenQuantityForEth(uint ethAmount) public pure returns (uint) {
        return ethAmount / ETH_TO_TOKEN_PRICE;
    }

    function checkRemainingSupply() external view returns (uint) {
        return balanceOf(address(this));
    }

    function balanceOf(address _owner) public view returns (uint256) {
        if (_owner == address(0)) revert MyERC20__AddressZeroError();
        return _balances[_owner];
    }

    function transfer(
        address _to,
        uint256 _value
    ) public returns (bool success) {
        if (_balances[msg.sender] < _value) revert MyERC20__InsufficientFunds();

        _balances[msg.sender] -= _value;
        _balances[_to] += _value;

        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) public returns (bool) {
        if (_allowances[_from][msg.sender] < _value)
            revert MyERC20__InsufficientAllowance();

        if (_balances[_from] < _value) revert MyERC20__InsufficientFunds();

        _balances[_from] -= _value;
        _balances[_to] += _value;
        _allowances[_from][msg.sender] -= _value;

        emit Transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool) {
        if (!(_balances[msg.sender] > 0 && _balances[msg.sender] >= _value))
            revert MyERC20__InsufficientFunds();

        _allowances[msg.sender][_spender] = _value;

        emit Approval(msg.sender, _spender, _value);

        return true;
    }

    function allowance(
        address _owner,
        address _spender
    ) public view returns (uint256) {
        return _allowances[_owner][_spender];
    }

    function name() external view override returns (string memory) {
        return NAME;
    }

    function symbol() external view returns (string memory) {
        return SYMBOL;
    }

    function decimals() external view override returns (uint256) {
        return DECIMALS;
    }

    function totalSupply() external view override returns (uint256) {
        return TOTAL_SUPPLY;
    }

    receive() external payable {}
}


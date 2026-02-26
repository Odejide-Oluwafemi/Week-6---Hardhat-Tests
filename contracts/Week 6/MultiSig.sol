// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.3;

contract MultiSigWallet {
//   =====================================================================================
//   |                                                                                   |
//   |  1. At Deployment, all Signers addresses will be provided                         |
//   |                                                                                   |
//   |  2. Any signer can Create Product to be sold on the platform                      |
//   |                                                                                   |
//   |  3. External Users can buy products from the contract (payment in ETH)            |
//   |                                                                                   |
//   |  4. (2/3) signers must approve before a Withdrawal can be made                    |
//   |                                                                                   |
//   =====================================================================================

    // Errors
    error NoProductAvailableAtTheMomemt__CheckAgainLater();
    error OnlySignersCanInitiateThisTransaction();
    error InvalidPurchaseAmount();
    error NeedsMoreApproval();
    error InvalidProductId();
    error ProductAlreadyExists();

    // Enum
    enum Action {
        ChangeApproverCount,
        Withdrawal
    }

    // Struct
    struct Product {
        uint id;
        string name;
        uint cost;
    }

    // State Variables
    address[] public signers;
    uint8 numberOfApprovalNeeded;

    mapping (address signer => bool hasSigned) public signerToHasSigned;
    // mapping (address signer => uint approvalAmount) public signerToAmountApproved;
    mapping (address signer => uint amountRequest) public amountRequestedBySigner;
    mapping (address signer => mapping (address signerRequesting => uint amountApproved)) public amountApprovedToRequester;
    mapping (address signer => mapping (address signerRequesting => mapping (Action action => bool approved))) public actionHasBeenApprovedToRequester;
    // mapping (address signer => mapping (address signerRequesting => ))
    
    Product[] private allProducts;
    mapping (uint id => Product productDetail) public idToProductDetail;
    mapping (string name => uint id) public productNameToId;

    constructor(address _signer1, address _signer2, address _signer3, uint8 _approvalCountNeeded) {
        require(((_signer1 != _signer2) && ( _signer2 != _signer3) && (_signer1 != _signer3)), "Duplicate Signer Addresses Found!!!");
        require(_approvalCountNeeded > 0 && _approvalCountNeeded < 3, "Invalid Approval Count!");

        // Add to Array
        signers.push(_signer1);
        signers.push(_signer2);
        signers.push(_signer3);

        numberOfApprovalNeeded = _approvalCountNeeded;
    }

    // Modifiers
    modifier onlyValidSigner() {
        bool valid;

        for (uint i; i < signers.length; i++) {
            if (msg.sender == signers[i]) {
                valid = true;
                break;
            }
        }

        if (!valid) revert OnlySignersCanInitiateThisTransaction();
        _;
    }

    modifier onlyWhenApproved(address signerToBeApproved) {
        uint signedCount = 0;

        for(uint i; i < signers.length; i++) {
            if (signers[i] == signerToBeApproved)   continue;   // Signer requesting approval should't be counted

            if (
                signerToHasSigned[signers[i]] == true
                &&
                // signerToAmountApproved[signers[i]] == amountRequestedBySigner[signerToBeApproved]
                amountApprovedToRequester[signers[i]][signerToBeApproved] >= amountRequestedBySigner[signerToBeApproved]

            ) signedCount = signedCount + 1;
        }

        if (signedCount < numberOfApprovalNeeded) revert NeedsMoreApproval();
        _;
    }

    modifier onlyWhenActionApproved(address signerToBeApproved, Action _action) {
        uint signedCount = 0;

        for(uint i; i < signers.length; i++) {
            if (signers[i] == signerToBeApproved)   continue;   // Signer requesting approval should't be counted

            if (actionHasBeenApprovedToRequester[signers[i]][signerToBeApproved][_action]) signedCount = signedCount + 1;
        }

        if (signedCount < numberOfApprovalNeeded) revert NeedsMoreApproval();
        _;
    }

    function changeApproverCount(uint8 count) public onlyValidSigner onlyWhenActionApproved(msg.sender, Action.ChangeApproverCount) {
        resetActionApproval(msg.sender, Action.ChangeApproverCount);

        numberOfApprovalNeeded = count;
    }

    function createProduct(string memory _name, uint _cost) public onlyValidSigner {
        if (productNameToId[_name] != 0) revert ProductAlreadyExists();
        uint _id = block.timestamp;

        Product memory product = Product({
            id: _id,
            name: _name,
            cost: _cost
        });

        allProducts.push(product);
        idToProductDetail[_id] = product;
        productNameToId[_name] = _id;
    }

    function buyProduct(uint _id) external payable {
        require (isValidSigner(msg.sender) == false, "Signers cannot purchase");
        if (msg.value == 0) revert InvalidPurchaseAmount();
        if (allProducts.length == 0) revert NoProductAvailableAtTheMomemt__CheckAgainLater();

        Product memory product = idToProductDetail[_id];

        if (product.id == 0) revert InvalidProductId();
        if (msg.value < product.cost) revert InvalidPurchaseAmount();
        
        (uint productIndex, bool found) = getProductIndex(_id);

        require(found);

        allProducts[productIndex] = allProducts[allProducts.length - 1];
        allProducts.pop();
        idToProductDetail[_id] = Product({
            id: 0,
            name: "",
            cost: 0
        });
        productNameToId[product.name] = 0;
    }

    function createApprovalRequest(uint amount) external onlyValidSigner {
        amountRequestedBySigner[msg.sender] = amount;
    }

    function withdraw(uint amount) external onlyValidSigner onlyWhenApproved(msg.sender) {
        resetApprovalsAfterTransaction(msg.sender);

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Withdraw Failed");
    }

    function approve(address signerRequesting, bool isApproving, uint amountToApprove) external onlyValidSigner {
        require(isValidSigner(signerRequesting));
        require(msg.sender != signerRequesting);

        signerToHasSigned[msg.sender] = isApproving;
        // signerToAmountApproved[msg.sender] = amountToApprove;
        amountApprovedToRequester[msg.sender][signerRequesting] = amountToApprove;
    }

    function approveActionTo(address signerRequesting, Action _action) external onlyValidSigner {
        require (signerRequesting != msg.sender, "Invalid Signer!");

        actionHasBeenApprovedToRequester[msg.sender][signerRequesting][_action] = true;
    }

    function resetApprovalsAfterTransaction(address requester) private {
      for (uint i; i < signers.length; i++) {
        if (signers[i] == requester) continue;

        signerToHasSigned[signers[i]] = false;

        amountApprovedToRequester[signers[i]][requester] = 0;
      }

      amountRequestedBySigner[requester] = 0;
    }

    function resetActionApproval(address requester, Action _action) private {
        for (uint i; i < signers.length; i++) {
            if (signers[i] == requester) continue;

            actionHasBeenApprovedToRequester[signers[i]][requester][_action] = false;
        }
    }

    // External Functions
    function getProductDetails(uint index) external  view  returns (Product memory) {
        return allProducts[index];
    }

    function getProductIndex(uint _id) public view returns(uint productIndex, bool found) {
            for(uint index; index < allProducts.length; index++) {
                if (allProducts[index].id == _id) {
                    found = true;
                    productIndex = index;
                }
            }
        }

    function isValidSigner(address signer) private view returns (bool) {
        bool valid;

        for (uint i; i < signers.length; i++) {
            if (signer == signers[i]) {
                valid = true;
                break;
            }
        }

        return valid;
    }

    function getAllProductLength() external view returns (uint) {
        return allProducts.length;
    }
}

//   =====================================================================================
//   |                                                                                   |
//   |  1. At Deployment, all Signers addresses will be provided                         |
//   |                                                                                   |
//   |  2. Any signer can Create Product to be sold on the platform                      |
//   |                                                                                   |
//   |  3. External Users can buy products from the contract (payment in ETH)            |
//   |                                                                                   |
//   |  4. (2/3) signers must approve before a Withdrawal can be made                    |
//   |                                                                                   |
//   =====================================================================================

// 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4, 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2, 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db, 2
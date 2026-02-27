// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.3;

contract MultiSigWallet {
    //   =====================================================================================
    //   |                                                                                   |
    //   |  1. At Deployment, all 3 Signers addresses will be provided                       |
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

    // Events
    event ContractDeployed(address[] indexed signers, uint256 numberOfApprovalNeeded);
    event NumberOfApprovalNeededChanged(uint256 indexed numberOfApprovalNeeded, uint256 oldCount);
    event ProductCreated(Product product);
    event ProductPurchased(address buyer, Product productDetails);
    event ApprovalRequestCreated(address bySigner, uint256 amountRequested);
    event Withdrawal(address signer, uint256 amountWithdrawn);
    event ApprovalSet(
        address indexed signer, address indexed signerRequesting, uint256 indexed amountToApprove, bool isApproving
    );
    event ActionApprovalSet(address indexed signer, address indexed signerRequesting, Action action);

    // Enum
    enum Action {
        ChangeApproverCount,
        Withdrawal
    }

    // Struct
    struct Product {
        uint256 id;
        string name;
        uint256 cost;
    }

    // State Variables
    address[] public signers;
    uint8 numberOfApprovalNeeded;

    mapping(address signer => bool hasSigned) public signerToHasSigned;
    // mapping (address signer => uint approvalAmount) public signerToAmountApproved;
    mapping(address signer => uint256 amountRequest) public amountRequestedBySigner;
    mapping(address signer => mapping(address signerRequesting => uint256 amountApproved)) public
        amountApprovedToRequester;
    mapping(address signer => mapping(address signerRequesting => mapping(Action action => bool approved))) public
        actionHasBeenApprovedToRequester;
    // mapping (address signer => mapping (address signerRequesting => ))

    Product[] private allProducts;
    mapping(uint256 id => Product productDetail) public idToProductDetail;
    mapping(string name => uint256 id) public productNameToId;

    constructor(address _signer1, address _signer2, address _signer3, uint8 _approvalCountNeeded) {
        require(
            ((_signer1 != _signer2) && (_signer2 != _signer3) && (_signer1 != _signer3)),
            "Duplicate Signer Addresses Found!!!"
        );
        require(_approvalCountNeeded > 0 && _approvalCountNeeded < 3, "Invalid Approval Count!");

        // Add to Array
        signers.push(_signer1);
        signers.push(_signer2);
        signers.push(_signer3);

        numberOfApprovalNeeded = _approvalCountNeeded;

        emit ContractDeployed(signers, numberOfApprovalNeeded);
    }

    // Modifiers
    modifier onlyValidSigner() {
        _onlyValidSigner();
        _;
    }

    modifier onlyWhenApproved(address signerToBeApproved) {
        _onlyWhenApproved(signerToBeApproved);
        _;
    }

    modifier onlyWhenActionApproved(address signerToBeApproved, Action _action) {
        _onlyWhenActionApproved(signerToBeApproved, _action);
        _;
    }

    function changeApproverCount(uint8 count)
        public
        onlyValidSigner
        onlyWhenActionApproved(msg.sender, Action.ChangeApproverCount)
    {
        uint256 oldCount = numberOfApprovalNeeded;

        resetActionApproval(msg.sender, Action.ChangeApproverCount);
        numberOfApprovalNeeded = count;

        emit NumberOfApprovalNeededChanged(numberOfApprovalNeeded, oldCount);
    }

    function createProduct(string memory _name, uint256 _cost) public onlyValidSigner {
        if (productNameToId[_name] != 0) revert ProductAlreadyExists();
        uint256 _id = block.timestamp;

        Product memory product = Product({id: _id, name: _name, cost: _cost});

        allProducts.push(product);
        idToProductDetail[_id] = product;
        productNameToId[_name] = _id;

        emit ProductCreated(product);
    }

    function buyProduct(uint256 _id) external payable {
        require(isValidSigner(msg.sender) == false, "Signers cannot purchase");
        if (msg.value == 0) revert InvalidPurchaseAmount();
        if (allProducts.length == 0) revert NoProductAvailableAtTheMomemt__CheckAgainLater();

        Product memory product = idToProductDetail[_id];

        if (product.id == 0) revert InvalidProductId();
        if (msg.value < product.cost) revert InvalidPurchaseAmount();

        (uint256 productIndex, bool found) = getProductIndex(_id);

        require(found);

        allProducts[productIndex] = allProducts[allProducts.length - 1];
        allProducts.pop();
        idToProductDetail[_id] = Product({id: 0, name: "", cost: 0});
        productNameToId[product.name] = 0;

        emit ProductPurchased(msg.sender, product);
    }

    function createApprovalRequest(uint256 amount) external onlyValidSigner {
        amountRequestedBySigner[msg.sender] = amount;

        emit ApprovalRequestCreated(msg.sender, amount);
    }

    function withdraw(uint256 amount) external onlyValidSigner onlyWhenApproved(msg.sender) {
        resetApprovalsAfterTransaction(msg.sender);

        (bool success,) = payable(msg.sender).call{value: amount}("");
        require(success, "Withdraw Failed");

        emit Withdrawal(msg.sender, amount);
    }

    function approve(address signerRequesting, bool isApproving, uint256 amountToApprove) external onlyValidSigner {
        require(isValidSigner(signerRequesting));
        require(msg.sender != signerRequesting);

        signerToHasSigned[msg.sender] = isApproving;
        // signerToAmountApproved[msg.sender] = amountToApprove;
        amountApprovedToRequester[msg.sender][signerRequesting] = amountToApprove;

        emit ApprovalSet(msg.sender, signerRequesting, amountToApprove, isApproving);
    }

    function approveActionTo(address signerRequesting, Action _action) external onlyValidSigner {
        require(signerRequesting != msg.sender, "Invalid Signer!");

        actionHasBeenApprovedToRequester[msg.sender][signerRequesting][_action] = true;

        emit ActionApprovalSet(msg.sender, signerRequesting, _action);
    }

    function resetApprovalsAfterTransaction(address requester) private {
        for (uint256 i; i < signers.length; i++) {
            if (signers[i] == requester) continue;

            signerToHasSigned[signers[i]] = false;

            amountApprovedToRequester[signers[i]][requester] = 0;
        }

        amountRequestedBySigner[requester] = 0;
    }

    function resetActionApproval(address requester, Action _action) private {
        for (uint256 i; i < signers.length; i++) {
            if (signers[i] == requester) continue;

            actionHasBeenApprovedToRequester[signers[i]][requester][_action] = false;
        }
    }

    // Modifier Check Functions
    function _onlyValidSigner() internal view {
        bool valid;

        for (uint256 i; i < signers.length; i++) {
            if (msg.sender == signers[i]) {
                valid = true;
                break;
            }
        }

        if (!valid) revert OnlySignersCanInitiateThisTransaction();
    }

    function _onlyWhenApproved(address signerToBeApproved) internal view {
        uint256 signedCount = 0;
        for (uint256 i; i < signers.length; i++) {
            if (signers[i] == signerToBeApproved) continue; // Signer requesting approval should't be counted

            if (
                signerToHasSigned[signers[i]] == true && 
                    // signerToAmountApproved[signers[i]] == amountRequestedBySigner[signerToBeApproved]
                    amountApprovedToRequester[signers[i]][signerToBeApproved]
                        >= amountRequestedBySigner[signerToBeApproved]
            ) signedCount = signedCount + 1;
        }
        if (signedCount < numberOfApprovalNeeded) revert NeedsMoreApproval();
    }

    function _onlyWhenActionApproved(address signerToBeApproved, Action _action) internal view {
        uint256 signedCount = 0;

        for (uint256 i; i < signers.length; i++) {
            if (signers[i] == signerToBeApproved) continue; // Signer requesting approval should't be counted

            if (actionHasBeenApprovedToRequester[signers[i]][signerToBeApproved][_action]) {
                signedCount = signedCount + 1;
            }
        }

        if (signedCount < numberOfApprovalNeeded) revert NeedsMoreApproval();
    }

    // External Functions
    function getProductDetails(uint256 index) external view returns (Product memory) {
        return allProducts[index];
    }

    function getProductIndex(uint256 _id) public view returns (uint256 productIndex, bool found) {
        for (uint256 index; index < allProducts.length; index++) {
            if (allProducts[index].id == _id) {
                found = true;
                productIndex = index;
            }
        }
    }

    function isValidSigner(address signer) private view returns (bool) {
        bool valid;

        for (uint256 i; i < signers.length; i++) {
            if (signer == signers[i]) {
                valid = true;
                break;
            }
        }

        return valid;
    }

    function getAllProductLength() external view returns (uint256) {
        return allProducts.length;
    }

    function getAllSigners() external view returns (address[] memory) {
        return signers;
    }
}

//   =====================================================================================
//   |                                                                                   |
//   |  1. At Deployment, all 3 Signers addresses will be provided                       |
//   |                                                                                   |
//   |  2. Any signer can Create Product to be sold on the platform                      |
//   |                                                                                   |
//   |  3. External Users can buy products from the contract (payment in ETH)            |
//   |                                                                                   |
//   |  4. (2/3) signers must approve before a Withdrawal can be made                    |
//   |                                                                                   |
//   =====================================================================================

// 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4, 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2, 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db, 2

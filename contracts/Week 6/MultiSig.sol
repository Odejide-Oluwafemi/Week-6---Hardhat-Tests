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
    error OnlySignersCanInitiateThisTransaction();
    error InvalidPurchaseAmount();
    error NeedsMoreApproval();

    // Struct
    struct Product {
        string name;
        uint cost;
    }

    // State Variables
    address[] public signers;
    mapping (address signer => bool hasSigned) public signerToHasSigned;
    Product[] private allProducts;

    constructor(address _signer1, address _signer2, address _signer3) {
        require(((_signer1 != _signer2) && ( _signer2 != _signer3) && (_signer1 != _signer3)), "Duplicate Signer Addresses Found!!!");

        // Add to Array
        signers.push(_signer1);
        signers.push(_signer2);
        signers.push(_signer3);

        // Set hasSigned status to false
        signerToHasSigned[_signer1] = false;
        signerToHasSigned[_signer2] = false;
        signerToHasSigned[_signer3] = false;
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

    modifier onlyWhenApproved() {
        uint signedCount = 0;

        for(uint i; i < signers.length; i++) {
            if (signerToHasSigned[signers[i]] == true) signedCount = signedCount + 1;
        }

        if (signedCount < 2) revert NeedsMoreApproval();
        _;
    }

    function createProduct(string memory _name, uint _cost) public onlyValidSigner {
        allProducts.push(Product({
            name: _name,
            cost: _cost
        }));
    }

    function buyProduct(string memory _name) external payable {
        if(msg.value == 0) revert InvalidPurchaseAmount();

        for(uint i; i< allProducts.length; i++) {
            if (keccak256(abi.encodePacked(allProducts[i].name)) == keccak256(abi.encodePacked(_name))) {
                if (msg.value == allProducts[i].cost) {
                    allProducts[i] = allProducts[allProducts.length - 1];
                    allProducts.pop();
                }
                else revert InvalidPurchaseAmount();
            }
        }
    }

    function withdraw(uint amount) external onlyValidSigner onlyWhenApproved {
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Withdraw Failed");

        resetApprovalsAfterTransaction();
    }

    function approve(bool isApproving) external onlyValidSigner {
        signerToHasSigned[msg.sender] = isApproving;
    }

    function resetApprovalsAfterTransaction() private {
      for (uint i; i < signers.length; i++) {
        signerToHasSigned[signers[i]] = false;
        signerToHasSigned[signers[i]] = false;
        signerToHasSigned[signers[i]] = false;
      }
    }

    // External Functions
    function getProductDetails(uint index) external  view  returns (Product memory) {
        return allProducts[index];
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
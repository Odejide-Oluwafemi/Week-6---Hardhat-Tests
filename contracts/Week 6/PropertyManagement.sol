// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PropertyToken is ERC20 {
    constructor(string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }
}

 contract PropertyManagement {
        // Errors
        error Property__InvalidPrice();
        error Property__OnlyThePropertyOwnerCanPerformThisAction();
        error Property__PropertyListingFailed();
        error Property__404_NotFound();
        error Property__PurchaseFailed();
        error Property__ThisPropertyIsNotListedForSale();

        // Events
        event PropertyListed(address indexed owner, uint indexed propertyIndex, uint timestamp);
        event PropertyDelisted(address indexed owner, uint indexed propertyIndex, uint timestamp);
        event PropertyPurchased(address indexed seller, address indexed buyer, uint indexed propertyId, uint propertyPrice);

        // State Variables
        uint constant public PROPERTY_LISTING_PRICE = 1000;
        PropertyToken immutable token;
        
        struct Property {
            uint id;
            string name;
            uint price;
            bool isListedForSale;
            address owner;
        }
        
        Property[] private allProperties;
        mapping(uint propertyId => Property property) private idToProperty;

        // Modifier
        modifier onlyPropertyOwner(uint _id) {
            if (idToProperty[_id].owner != msg.sender) revert Property__OnlyThePropertyOwnerCanPerformThisAction();
            _;
        }

        // Functions
        constructor(address tokenAddress) {
            token = PropertyToken(tokenAddress);
        }

        function listNewProperty(string memory _name, uint256 _price) public {
            if (_price == 0) revert Property__InvalidPrice();
            
            bool success = token.transferFrom(msg.sender, address(this), PROPERTY_LISTING_PRICE);
            if(!success) revert Property__PropertyListingFailed();

            uint256 _id = block.timestamp;

            Property memory newProperty = Property({
                id: _id,
                name: _name,
                price: _price,
                isListedForSale: false,
                owner: msg.sender
            });

            allProperties.push(newProperty);
            idToProperty[_id] = newProperty;

            emit PropertyListed(newProperty.owner, newProperty.id, block.timestamp);
        }

        function delistProperty(uint _id) public onlyPropertyOwner(_id) {
            uint propertyIndex = getPropertyIndex(_id);

            Property storage property = allProperties[propertyIndex];

            if(property.owner == address(0)) revert Property__404_NotFound();

            allProperties[propertyIndex] = allProperties[allProperties.length - 1];
            allProperties.pop();

            idToProperty[_id] = Property(0, "", 0, false, address(0));

            emit PropertyDelisted(msg.sender, propertyIndex, block.timestamp);
        }

        function setPropertyForSale(uint _id, bool forSale) public onlyPropertyOwner(_id) {
            Property storage property = idToProperty[_id];
            property.isListedForSale = forSale;
            allProperties[getPropertyIndex(_id)] = property;
        }

        function buyProperty(uint _id) public {
            Property storage property = allProperties[getPropertyIndex(_id)];
            if (!property.isListedForSale) revert Property__ThisPropertyIsNotListedForSale();

            address initialOwner = property.owner;
            bool success = token.transferFrom(msg.sender, property.owner, property.price);

            if (!success) revert Property__PurchaseFailed();

            property.owner = msg.sender;
            property.isListedForSale = false;
            idToProperty[_id] = property;

            emit PropertyPurchased(initialOwner, msg.sender, property.id, property.price);
        }

        //=========================
        //    Getter Functions
        //=========================
        function getPropertyById(uint _id) external view returns (Property memory) {
            return idToProperty[_id];
        }

        function getAllProperties() external view returns (Property[] memory) {
            return allProperties;
        }

        function getPropertyIndex(uint _id) public view returns(uint propertyIndex) {
            for(uint index; index < allProperties.length; index++) {
                if (allProperties[index].id == _id) {
                    propertyIndex = index;
                }
            }
        }

        function getTokenAddress() external view returns(address) {
            return address(token);
        }
    }
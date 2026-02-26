// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract MyNft is ERC721URIStorage {
  constructor() ERC721("MyNFT", "MNFT") {}

  function mint(address _to, uint256 _tokenId, string calldata _tokenUri) external {
    _mint(_to, _tokenId);
    _setTokenURI(_tokenId, _tokenUri);
  }
}
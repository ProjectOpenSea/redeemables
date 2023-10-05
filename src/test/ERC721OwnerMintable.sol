// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC721ConduitPreapproved_Solady} from "shipyard-core/src/tokens/erc721/ERC721ConduitPreapproved_Solady.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";

contract ERC721OwnerMintable is ERC721ConduitPreapproved_Solady, Ownable {
    constructor() ERC721ConduitPreapproved_Solady() {
        _initializeOwner(msg.sender);
    }

    function mint(address to, uint256 tokenId) public onlyOwner {
        _mint(to, tokenId);
    }

    function name() public pure override returns (string memory) {
        return "ERC721OwnerMintable";
    }

    function symbol() public pure override returns (string memory) {
        return "ERC721-OM";
    }

    function tokenURI(uint256 /* tokenId */ ) public pure override returns (string memory) {
        return "https://example.com/";
    }
}

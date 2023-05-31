// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { ERC721 } from "solady/tokens/ERC721.sol";
import { Ownable } from "solady/auth/Ownable.sol";

contract Test721 is ERC721, Ownable {
    constructor() {
        _initializeOwner(msg.sender);
    }

    function name() public view virtual override returns (string memory) {
        return "Test721";
    }

    function symbol() public view virtual override returns (string memory) {
        return "TEST";
    }

    function mint(address to, uint256 tokenId) public onlyOwner {
        _mint(to, tokenId);
    }

    function tokenURI(uint256 /* tokenId */ )
        public
        view
        virtual
        override
        returns (string memory)
    {
        return "";
    }
}

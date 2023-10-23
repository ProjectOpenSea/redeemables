// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC721SeaDropRedeemable} from "../ERC721SeaDropRedeemable.sol";

contract ERC721SeaDropRedeemableOwnerMintable is ERC721SeaDropRedeemable {
    constructor(address allowedConfigurer, address allowedSeaport, string memory name_, string memory symbol_)
        ERC721SeaDropRedeemable(allowedConfigurer, allowedSeaport, name_, symbol_)
    {}

    function mint(address to, uint256 tokenId) public onlyOwner {
        _mint(to, tokenId);
    }
}

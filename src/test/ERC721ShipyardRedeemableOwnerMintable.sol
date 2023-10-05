// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC721ShipyardRedeemable} from "../ERC721ShipyardRedeemable.sol";

contract ERC721ShipyardRedeemableOwnerMintable is ERC721ShipyardRedeemable {
    constructor() ERC721ShipyardRedeemable() {}

    function mint(address to, uint256 tokenId) public onlyOwner {
        _mint(to, tokenId);
    }
}

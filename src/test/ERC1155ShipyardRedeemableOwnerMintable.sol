// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC1155ShipyardRedeemable} from "../ERC1155ShipyardRedeemable.sol";

contract ERC1155ShipyardRedeemableOwnerMintable is ERC1155ShipyardRedeemable {
    constructor(string memory name_, string memory symbol_) ERC1155ShipyardRedeemable(name_, symbol_) {}

    function mint(address to, uint256 tokenId, uint256 amount) public onlyOwner {
        _mint(to, tokenId, amount, "");
    }
}

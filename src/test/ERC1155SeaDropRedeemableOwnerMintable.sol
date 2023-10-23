// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC1155SeaDropRedeemable} from "../ERC1155SeaDropRedeemable.sol";

contract ERC1155SeaDropRedeemableOwnerMintable is ERC1155SeaDropRedeemable {
    constructor(address allowedConfigurer, address allowedSeaport, string memory name_, string memory symbol_)
        ERC1155SeaDropRedeemable(allowedConfigurer, allowedSeaport, name_, symbol_)
    {}

    function mint(address to, uint256 tokenId, uint256 amount) public onlyOwner {
        _mint(to, tokenId, amount, "");
    }
}

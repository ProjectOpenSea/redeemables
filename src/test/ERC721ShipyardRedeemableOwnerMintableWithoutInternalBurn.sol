// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC7498NFTRedeemables} from "../lib/ERC7498NFTRedeemables.sol";
import {ERC721ShipyardRedeemableOwnerMintable} from "./ERC721ShipyardRedeemableOwnerMintable.sol";

contract ERC721ShipyardRedeemableOwnerMintableWithoutInternalBurn is ERC721ShipyardRedeemableOwnerMintable {
    constructor(string memory name_, string memory symbol_) ERC721ShipyardRedeemableOwnerMintable(name_, symbol_) {}

    function _useInternalBurn() internal pure virtual override returns (bool) {
        // For coverage of ERC7498NFTRedeemables._useInternalBurn, return default value of false.
        return ERC7498NFTRedeemables._useInternalBurn();
    }
}

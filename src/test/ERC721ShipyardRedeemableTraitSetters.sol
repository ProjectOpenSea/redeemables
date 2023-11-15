// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC721ShipyardRedeemableOwnerMintable} from "./ERC721ShipyardRedeemableOwnerMintable.sol";
import {ERC7498NFTRedeemables} from "../lib/ERC7498NFTRedeemables.sol";
import {DynamicTraits} from "shipyard-core/src/dynamic-traits/DynamicTraits.sol";
import {CampaignParams} from "../lib/RedeemablesStructs.sol";

contract ERC721ShipyardRedeemableTraitSetters is ERC721ShipyardRedeemableOwnerMintable {
    // TODO add the `allowedTraitSetters` logic to DynamicTraits.sol contract in shipyard-core
    // with getAllowedTraitSetters() and setAllowedTraitSetters(). add `is DynamicTraits` to
    // ERC721ShipyardRedeemable and ERC721SeaDropRedeemable contracts with onlyOwner on setAllowedTraitSetters().
    address[] _allowedTraitSetters;

    constructor(string memory name_, string memory symbol_, address[] memory allowedTraitSetters)
        ERC721ShipyardRedeemableOwnerMintable(name_, symbol_)
    {
        _allowedTraitSetters = allowedTraitSetters;
    }

    function setTrait(uint256 tokenId, bytes32 traitKey, bytes32 value) public virtual override {
        if (!_exists(tokenId)) revert TokenDoesNotExist();

        _requireAllowedTraitSetter();

        DynamicTraits.setTrait(tokenId, traitKey, value);
    }

    function getTraitValue(uint256 tokenId, bytes32 traitKey)
        public
        view
        virtual
        override
        returns (bytes32 traitValue)
    {
        if (!_exists(tokenId)) revert TokenDoesNotExist();

        traitValue = DynamicTraits.getTraitValue(tokenId, traitKey);
    }

    function _requireAllowedTraitSetter() internal view {
        // Allow the contract to call itself.
        if (msg.sender == address(this)) return;

        bool validCaller;
        for (uint256 i; i < _allowedTraitSetters.length; i++) {
            if (_allowedTraitSetters[i] == msg.sender) {
                validCaller = true;
            }
        }
        if (!validCaller) revert InvalidCaller(msg.sender);
    }
}

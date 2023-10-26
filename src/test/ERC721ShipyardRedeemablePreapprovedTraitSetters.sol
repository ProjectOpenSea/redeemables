// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC721ShipyardRedeemableOwnerMintable} from "./ERC721ShipyardRedeemableOwnerMintable.sol";
import {ERC7498NFTRedeemables} from "../lib/ERC7498NFTRedeemables.sol";
import {DynamicTraits} from "shipyard-core/src/dynamic-traits/DynamicTraits.sol";
import {CampaignParams} from "../lib/RedeemablesStructs.sol";

contract ERC721ShipyardRedeemablePreapprovedTraitSetters is ERC721ShipyardRedeemableOwnerMintable {
    address[] public allowedTraitSetters;

    constructor(string memory name_, string memory symbol_, address[] memory allowedTraitSetters_)
        ERC721ShipyardRedeemableOwnerMintable(name_, symbol_)
    {
        allowedTraitSetters = allowedTraitSetters_;
    }

    function setTrait(uint256 tokenId, bytes32 traitKey, bytes32 value) public virtual override {
        if (!_exists(tokenId)) {
            revert TokenDoesNotExist();
        }

        if (!_isPreapprovedTraitSetter(msg.sender)) {
            revert InvalidCaller(msg.sender);
        }

        DynamicTraits.setTrait(tokenId, traitKey, value);
    }

    function getTraitValue(uint256 tokenId, bytes32 traitKey)
        public
        view
        virtual
        override
        returns (bytes32 traitValue)
    {
        if (!_exists(tokenId)) {
            revert TokenDoesNotExist();
        }

        traitValue = DynamicTraits.getTraitValue(tokenId, traitKey);
    }

    function _useInternalBurn() internal pure virtual override returns (bool) {
        return true;
    }

    function _internalBurn(
        address,
        /* from */
        uint256 id,
        uint256 /* amount */
    ) internal virtual override {
        _burn(id);
    }

    function _isPreapprovedTraitSetter(address traitSetter) internal view returns (bool) {
        for (uint256 i = 0; i < allowedTraitSetters.length; i++) {
            if (allowedTraitSetters[i] == traitSetter) {
                return true;
            }
        }

        return false;
    }
}

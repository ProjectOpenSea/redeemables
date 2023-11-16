// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC721ShipyardContractMetadata} from "./lib/ERC721ShipyardContractMetadata.sol";
import {ERC7498NFTRedeemables} from "./lib/ERC7498NFTRedeemables.sol";
import {DynamicTraits} from "shipyard-core/src/dynamic-traits/DynamicTraits.sol";
import {Campaign} from "./lib/RedeemablesStructs.sol";

contract ERC721ShipyardRedeemable is ERC721ShipyardContractMetadata, ERC7498NFTRedeemables {
    constructor(string memory name_, string memory symbol_) ERC721ShipyardContractMetadata(name_, symbol_) {}

    function createCampaign(Campaign calldata campaign, string calldata metadataURI)
        public
        override
        onlyOwner
        returns (uint256 campaignId)
    {
        campaignId = ERC7498NFTRedeemables.createCampaign(campaign, metadataURI);
    }

    function setTrait(uint256 tokenId, bytes32 traitKey, bytes32 value) public virtual override onlyOwner {
        if (!_exists(tokenId)) revert TokenDoesNotExist();

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

    function getTraitValues(uint256 tokenId, bytes32[] calldata traitKeys)
        public
        view
        virtual
        override
        returns (bytes32[] memory traitValues)
    {
        if (!_exists(tokenId)) revert TokenDoesNotExist();

        traitValues = DynamicTraits.getTraitValues(tokenId, traitKeys);
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

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721ShipyardContractMetadata, ERC7498NFTRedeemables)
        returns (bool)
    {
        return ERC721ShipyardContractMetadata.supportsInterface(interfaceId)
            || ERC7498NFTRedeemables.supportsInterface(interfaceId);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {DynamicTraits} from "shipyard-core/src/dynamic-traits/DynamicTraits.sol";

import {ERC721SeaDrop} from "seadrop/src/ERC721SeaDrop.sol";
import {ERC721SeaDropContractOfferer} from "seadrop/src/lib/ERC721SeaDropContractOfferer.sol";

import {ERC7498NFTRedeemables} from "./lib/ERC7498NFTRedeemables.sol";

contract ERC721SeaDropRedeemable is DynamicTraits, ERC721SeaDrop, ERC7498NFTRedeemables {
    constructor(address allowedConfigurer, address allowedSeaport, string memory _name, string memory _symbol)
        ERC721SeaDrop(allowedConfigurer, allowedSeaport, _name, _symbol)
    {}

    function tokenURI(uint256 /* tokenId */ ) public pure override returns (string memory) {
        return "https://example.com/";
    }

    function deleteTrait(bytes32 traitKey, uint256 tokenId) external override {}

    function setTrait(bytes32 traitKey, uint256 tokenId, bytes32 value) external override {}

    function createCampaign(CampaignParams calldata params, string calldata uri)
        external
        override
        onlyOwner
        returns (uint256 campaignId)
    {
        ERC7498NFTRedeemables.createCampaign(params, uri);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(DynamicTraits, ERC721SeaDropContractOfferer)
        returns (bool)
    {
        return interfaceId == type(IERC7498).interfaceId || DynamicTraits.supportsInterface(interfaceId)
            || ERC721SeaDropContractOfferer.supportsInterface(interfaceId);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {DynamicTraits} from "shipyard-core/src/dynamic-traits/DynamicTraits.sol";
import {ERC721SeaDrop} from "seadrop/src/ERC721SeaDrop.sol";
import {ERC721SeaDropContractOfferer} from "seadrop/src/lib/ERC721SeaDropContractOfferer.sol";
import {IERC7498} from "./interfaces/IERC7498.sol";
import {ERC7498NFTRedeemables} from "./lib/ERC7498NFTRedeemables.sol";
import {CampaignParams} from "./lib/RedeemablesStructs.sol";

contract ERC721SeaDropRedeemable is ERC721SeaDrop, ERC7498NFTRedeemables, DynamicTraits {
    constructor(address allowedConfigurer, address allowedSeaport, string memory _name, string memory _symbol)
        ERC721SeaDrop(allowedConfigurer, allowedSeaport, _name, _symbol)
    {}

    function deleteTrait(bytes32 traitKey, uint256 tokenId) external override {}

    function setTrait(bytes32 traitKey, uint256 tokenId, bytes32 value) external override {}

    function createCampaign(CampaignParams calldata params, string calldata uri)
        public
        override
        onlyOwner
        returns (uint256 campaignId)
    {
        campaignId = ERC7498NFTRedeemables.createCampaign(params, uri);
    }

    function _useInternalBurn() internal pure virtual override returns (bool) {
        return true;
    }

    function _internalBurn(address, /* from */ uint256 id, uint256 /* amount */ ) internal virtual override {
        _burn(id);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721SeaDropContractOfferer, ERC7498NFTRedeemables, DynamicTraits)
        returns (bool)
    {
        return ERC721SeaDropContractOfferer.supportsInterface(interfaceId) || interfaceId == type(IERC7498).interfaceId
            || DynamicTraits.supportsInterface(interfaceId);
    }
}

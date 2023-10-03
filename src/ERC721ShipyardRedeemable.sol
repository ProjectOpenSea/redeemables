// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC721ConduitPreapproved_Solady} from "shipyard-core/src/tokens/erc721/ERC721ConduitPreapproved_Solady.sol";
import {ERC20} from "solady/src/tokens/ERC20.sol";
import {ERC1155} from "solady/src/tokens/ERC1155.sol";
import {OfferItem, ConsiderationItem, SpentItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {ItemType} from "seaport-types/src/lib/ConsiderationEnums.sol";
import {IRedemptionMintable} from "./interfaces/IRedemptionMintable.sol";
import {CampaignParams} from "./lib/RedeemablesStructs.sol";
import {RedeemablesErrorsAndEvents} from "./lib/RedeemablesErrorsAndEvents.sol";
import {ERC7498NFTRedeemables} from "./lib/ERC7498NFTRedeemables.sol";

contract ERC721ShipyardRedeemable is ERC721ConduitPreapproved_Solady, ERC7498NFTRedeemables {
    constructor() ERC721ConduitPreapproved_Solady() {}

    function name() public pure override returns (string memory) {
        return "ERC721ShipyardRedeemable";
    }

    function symbol() public pure override returns (string memory) {
        return "ShipyardRDM";
    }

    function tokenURI(uint256 /* tokenId */ ) public pure override returns (string memory) {
        return "https://example.com/";
    }

    function createCampaign(CampaignParams calldata params, string calldata uri)
        external
        override
        onlyOwner
        returns (uint256 campaignId)
    {
        ERC7498NFTRedeemables.createCampaign(params, uri);
    }

    function _internalBurn(uint256 id) override {
        _burn(id);
    }
}

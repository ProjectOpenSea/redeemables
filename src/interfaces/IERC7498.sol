// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {OfferItem, ConsiderationItem, SpentItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {Campaign, TraitRedemption} from "../lib/RedeemablesStructs.sol";

interface IERC7498 {
    event CampaignUpdated(uint256 indexed campaignId, Campaign campaign, string metadataURI);
    event Redemption(
        uint256 indexed campaignId,
        uint256 requirementsIndex,
        bytes32 redemptionHash,
        uint256[] considerationTokenIds,
        uint256[] traitRedemptionTokenIds,
        address redeemedBy
    );

    function createCampaign(Campaign calldata campaign, string calldata metadataURI)
        external
        returns (uint256 campaignId);

    function updateCampaign(uint256 campaignId, Campaign calldata campaign, string calldata metadataURI) external;

    function getCampaign(uint256 campaignId)
        external
        view
        returns (Campaign memory campaign, string memory metadataURI, uint256 totalRedemptions);

    function redeem(uint256[] calldata considerationTokenIds, address recipient, bytes calldata extraData)
        external
        payable;
}

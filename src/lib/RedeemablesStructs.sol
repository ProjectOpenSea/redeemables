// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {OfferItem, ConsiderationItem, SpentItem} from "seaport-types/src/lib/ConsiderationStructs.sol";

struct Campaign {
    CampaignParams params;
    CampaignRequirements[] requirements;
}

struct CampaignParams {
    uint32 startTime;
    uint32 endTime;
    uint32 maxCampaignRedemptions;
    address manager;
    address signer;
}

struct CampaignRequirements {
    OfferItem[] offer;
    ConsiderationItem[] consideration;
    TraitRedemption[] traitRedemptions;
}

struct TraitRedemption {
    uint8 substandard;
    address token;
    bytes32 traitKey;
    bytes32 traitValue;
    bytes32 substandardValue;
}

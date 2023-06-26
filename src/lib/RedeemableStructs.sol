// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {OfferItem, ConsiderationItem} from "seaport-types/src/lib/ConsiderationStructs.sol";

struct CampaignParamsV0 {
    OfferItem[] offer;
    ConsiderationItem[] consideration;
    address signer;
    uint32 startTime;
    uint32 endTime;
    uint32 maxTotalRedemptions;
    // Additional parameters for registry functionality
    address manager;
}

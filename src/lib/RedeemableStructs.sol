// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {OfferItem, ConsiderationItem, SpentItem} from "seaport-types/src/lib/ConsiderationStructs.sol";

struct CampaignParams {
    OfferItem[] offer;
    ConsiderationItem[] consideration;
    address signer;
    uint32 startTime;
    uint32 endTime;
    uint32 maxTotalRedemptions;
    address manager;
}

struct RedemptionContext {
    SpentItem[] spent;
}

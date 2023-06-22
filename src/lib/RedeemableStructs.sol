// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {OfferItem, ConsiderationItem} from "seaport-types/src/lib/ConsiderationStructs.sol";

struct RedeemableParams {
    OfferItem[] offer;
    ConsiderationItem[] consideration;
    address sendTo;
    address requiredSigner;
    uint32 startTime;
    uint32 endTime;
    uint16 maxRedemptions;
    uint32 maxTotalRedemptions;
    bool redemptionValuesAreImmutable;
    bool redemptionSettingsAreImmutable;
}

struct RedeemableRegistryParamsV0 {
    // RedeemableParams
    OfferItem[] offer;
    ConsiderationItem[] consideration;
    address sendTo;
    address requiredSigner;
    uint32 startTime;
    uint32 endTime;
    uint32 maxTotalRedemptions;
    bool redemptionValuesAreImmutable;
    bool redemptionSettingsAreImmutable;
    // Additional parameters for registry functionality
    address registeredBy;
}

struct RedeemableRegistryParams {
    // RedeemableParams
    OfferItem[] offer;
    ConsiderationItem[] consideration;
    address sendTo;
    address requiredSigner;
    uint32 startTime;
    uint32 endTime;
    uint16 maxRedemptions;
    uint32 maxTotalRedemptions;
    bool redemptionValuesAreImmutable;
    bool redemptionSettingsAreImmutable;
    // Additional parameters for registry functionality
    uint8 mintWithContext;
    address registeredBy;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ConsiderationItem, OfferItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {TraitRedemption} from "../lib/RedeemablesStructs.sol";

interface IRedemptionMintable {
    function mintRedemption(
        uint256 campaignId,
        address recipient,
        OfferItem calldata offer,
        ConsiderationItem[] calldata consideration,
        TraitRedemption[] calldata traitRedemptions
    ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {CampaignParamsV0} from "./RedeemableStructs.sol";

interface RedeemableErrorsAndEvents {
    error InvalidCaller(address caller);
    error MaxRedemptionsReached(uint256 total, uint256 max);
    error MaxTotalRedemptionsReached(uint256 total, uint256 max);

    error NotActive(uint256 currentTimestamp, uint256 startTime, uint256 endTime);

    error NotManager();
    error RedeemMismatchedLengths();
    error TraitValueUnchanged(bytes32 traitKey, bytes32 value);
    error InvalidConsiderationLength(uint256 got, uint256 want);
    error InvalidConsiderationItem(address got, address want);
    error InvalidOfferLength(uint256 got, uint256 want);
    error OfferItemsNotAllowed();
    error NoConsiderationItems();
    error ConsiderationItemRecipientCannotBeZeroAddress();
    error ConsiderationRecipientNotFound(address token);

    error RedemptionValuesAreImmutable();

    // v0
    event CampaignUpdated(uint256 campaignId, CampaignParamsV0 params, string uri);
    event Redemption(address by, uint256 campaignId, address token, uint256[] tokenIds, bytes32 redemptionHash);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {RedemptionParams, RedemptionRegistryParams} from "./RedeemableStructs.sol";

interface RedeemablesErrorsAndEvents {
    error MaxRedemptionsReached(uint256 total, uint256 max);
    error MaxTotalRedemptionsReached(uint256 total, uint256 max);

    error NotActive(
        uint256 currentTimestamp,
        uint256 startTime,
        uint256 endTime
    );

    error NotOwnerOrApproved();
    error RedeemMismatchedLengths();
    error TraitValueUnchanged(bytes32 traitKey, bytes32 value);

    error RedemptionSettingsAreImmutable();
    error RedemptionValuesAreImmutable();

    event RedemptionParamsUpdated(RedemptionParams params);
    event RedemptionParamsUpdated(
        bytes32 paramsHash,
        RedemptionRegistryParams params
    );

    event Redeemed(uint256 tokenId, address by);
    event RedeemedBatch(uint256[] tokenIds, address by);
}

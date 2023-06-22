// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {RedeemableParams, RedeemableRegistryParams, RedeemableRegistryParamsV0} from "./RedeemableStructs.sol";

interface RedeemableErrorsAndEvents {
    error InvalidCaller(address caller);
    error MaxRedemptionsReached(uint256 total, uint256 max);
    error MaxTotalRedemptionsReached(uint256 total, uint256 max);

    error NotActive(
        uint256 currentTimestamp,
        uint256 startTime,
        uint256 endTime
    );

    error NotOwnerOrAllowed();
    error OperatorCannotBeZeroAddress();
    error DuplicateOperator();
    error OperatorNotPresent();
    error RedeemMismatchedLengths();
    error TraitValueUnchanged(bytes32 traitKey, bytes32 value);
    error UnsupportedTokenAddress(address got);
    error OfferItemsNotAllowed();
    error NoConsiderationItems();

    error RedemptionSettingsAreImmutable();
    error RedemptionValuesAreImmutable();

    event RedeemableParamsUpdated(RedeemableParams params);
    event RedeemableParamsUpdated(
        bytes32 paramsHash,
        RedeemableRegistryParams params
    );
    event RedeemableParamsUpdated(
        bytes32 paramsHash,
        RedeemableRegistryParamsV0 params
    );
    event RedeemableURIUpdated(bytes32 paramsHash, string uri);

    event OperatorUpdated(
        address operator,
        bytes32 redeemableParamsHash,
        bool allowed
    );

    event Redeemed(address token, uint256[] tokenIds, address by);
}

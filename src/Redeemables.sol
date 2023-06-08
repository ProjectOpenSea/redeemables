// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC721} from "forge-std/interfaces/IERC721.sol";
import {DynamicTraits} from "./lib/DynamicTraits.sol";
import {SignedRedeem} from "./lib/SignedRedeem.sol";
import {RedeemablesErrorsAndEvents} from "./lib/RedeemableErrorsAndEvents.sol";
import {RedemptionRegistryParams} from "./lib/RedeemableStructs.sol";

contract Redeemables is
    SignedRedeem,
    RedeemablesErrorsAndEvents,
    DynamicTraits
{
    /// @dev The redeemable parameters stored by their hash.
    mapping(bytes32 redemptionParamsHash => RedemptionRegistryParams RedemptionParams)
        private _redemptionParams;

    /// @dev The redeemable URIs stored by params hash.
    mapping(bytes32 redemptionParamsHash => string redeemableURI)
        private _redeemableURIs;

    /// @dev The total redemptions by params hash.
    mapping(bytes32 redemptionParamsHash => uint256 count) _totalRedemptions;

    constructor() {}

    function updateRedemptionParams(
        RedemptionRegistryParams calldata params
    ) external {
        bytes32 paramsHash = _getRedemptionParamsHash(params);

        if (
            params.registeredBy != msg.sender
            // && !isApprovedForRedemptionParamsHash(msg.sender, redemptionParamsHash)
        ) revert NotOwnerOrApproved();

        RedemptionRegistryParams storage existingParams = _redemptionParams[
            paramsHash
        ];

        if (existingParams.redemptionSettingsAreImmutable)
            revert RedemptionSettingsAreImmutable();

        _redemptionParams[paramsHash] = params;

        emit RedemptionParamsUpdated(paramsHash, params);
    }

    function updateRedeemableURI(
        bytes32 redemptionParamsHash
    ) external returns (string memory) {
        RedemptionRegistryParams storage params = _redemptionParams[
            redemptionParamsHash
        ];

        if (
            params.registeredBy != msg.sender
            // && !isApprovedForRedemptionParamsHash(msg.sender, redemptionParamsHash)
        ) revert NotOwnerOrApproved();

        return _redeemableURIs[redemptionParamsHash];
    }

    function ownerOverrideRedemptionCount(
        bytes32 redemptionParamsHash,
        uint256 tokenId,
        uint256 count
    ) external {
        RedemptionRegistryParams storage params = _redemptionParams[
            redemptionParamsHash
        ];

        if (
            params.registeredBy != msg.sender
            // && !isApprovedForRedemptionParamsHash(msg.sender, redemptionParamsHash)
        ) revert NotOwnerOrApproved();

        if (params.redemptionValuesAreImmutable)
            revert RedemptionValuesAreImmutable();

        _setTrait(tokenId, redemptionParamsHash, bytes32(count));
    }

    function redemptionStatsForToken(
        bytes32 redemptionParamsHash,
        uint256 tokenId
    ) public view returns (uint256 redeemedCount) {
        redeemedCount = uint256(getTrait(tokenId, redemptionParamsHash));
    }

    function redemptionStats(
        bytes32 redemptionParamsHash
    )
        public
        view
        returns (uint256 totalRedemptions, uint256 maxTotalRedemptions)
    {
        RedemptionRegistryParams storage params = _redemptionParams[
            redemptionParamsHash
        ];

        totalRedemptions = _totalRedemptions[redemptionParamsHash];
        maxTotalRedemptions = params.maxTotalRedemptions;
    }

    function getRedemptionParams(
        bytes32 redemptionParamsHash
    ) external view returns (RedemptionRegistryParams memory) {
        return _redemptionParams[redemptionParamsHash];
    }

    function redeemableURI(
        bytes32 redemptionParamsHash,
        uint256 tokenId
    ) external view returns (string memory) {
        return _redeemableURIs[redemptionParamsHash];
    }

    function redeem(
        bytes32 redemptionParamsHash,
        uint256[] calldata tokenIds,
        uint256[] calldata amounts,
        bytes calldata signature,
        uint256 salt
    ) public {
        RedemptionRegistryParams storage params = _redemptionParams[
            redemptionParamsHash
        ];

        uint256 tokenIdsLength = tokenIds.length;

        if (tokenIdsLength != amounts.length) revert RedeemMismatchedLengths();

        uint256 totalAmount;
        for (uint256 i = 0; i < tokenIdsLength; i++) {
            totalAmount += amounts[i];
        }

        if (
            _totalRedemptions[redemptionParamsHash] + totalAmount >
            params.maxTotalRedemptions
        )
            revert MaxTotalRedemptionsReached(
                _totalRedemptions[redemptionParamsHash] + totalAmount,
                params.maxTotalRedemptions
            );

        if (_redeemSigner != address(0)) {
            _verifySignatureAndRecordDigest(
                msg.sender,
                tokenIds,
                salt,
                signature
            );
        }

        address tokenAddress = params.requiredToRedeem[0].token;

        for (uint256 i = 0; i < tokenIdsLength; i++) {
            _redeem(
                redemptionParamsHash,
                tokenAddress,
                tokenIds[i],
                amounts[i],
                params.maxRedemptions
            );
        }

        if (tokenIdsLength == 1) {
            emit Redeemed(tokenIds[0], msg.sender);
        } else {
            emit RedeemedBatch(tokenIds, msg.sender);
        }
    }

    function _redeem(
        bytes32 redemptionParamsHash,
        address tokenAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 maxRedemptions
    ) internal {
        IERC721 token = IERC721(tokenAddress);
        address owner = token.ownerOf(tokenId);

        if (
            owner != msg.sender &&
            !token.isApprovedForAll(owner, msg.sender) &&
            token.getApproved(tokenId) != msg.sender
        ) revert NotOwnerOrApproved();

        uint256 count = redemptionStatsForToken(redemptionParamsHash, tokenId);

        if (count + amount > maxRedemptions)
            revert MaxRedemptionsReached(count + amount, maxRedemptions);

        _setTrait(tokenId, redemptionParamsHash, bytes32(count + amount));
        _totalRedemptions[redemptionParamsHash] += amount;

        for (uint256 i = 0; i < amount; i++) {
            // _burn(tokenId);
        }

        // params.receivedOnRedeem[0]._mint(owner, tokenId);
    }

    function _getRedemptionParamsHash(
        RedemptionRegistryParams calldata params
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(params));
    }

    function _checkActive(uint256 startTime, uint256 endTime) internal view {
        bool valid;

        // Check startTime <= block.timestamp < endTime
        assembly {
            valid := and(
                iszero(gt(startTime, timestamp())),
                gt(endTime, timestamp())
            )
        }

        if (!valid) revert NotActive(block.timestamp, startTime, endTime);
    }
}

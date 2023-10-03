// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {IERC721} from "openzeppelin-contracts/contracts/interfaces/IERC721.sol";
import {IERC1155} from "openzeppelin-contracts/contracts/interfaces/IERC1155.sol";
import {OfferItem, ConsiderationItem, SpentItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {ItemType} from "seaport-types/src/lib/ConsiderationEnums.sol";
import {DynamicTraits} from "shipyard-core/src/dynamic-traits/DynamicTraits.sol";
import {IERC7498} from "../interfaces/IERC7498.sol";
import {IRedemptionMintable} from "../interfaces/IRedemptionMintable.sol";
import {RedeemablesErrorsAndEvents} from "./RedeemablesErrorsAndEvents.sol";
import {CampaignParams, TraitRedemption} from "./RedeemablesStructs.sol";

contract ERC7498NFTRedeemables is IERC7498, RedeemablesErrorsAndEvents {
    /// @dev Counter for next campaign id.
    uint256 private _nextCampaignId = 1;

    /// @dev The campaign parameters by campaign id.
    mapping(uint256 campaignId => CampaignParams params) private _campaignParams;

    /// @dev The campaign URIs by campaign id.
    mapping(uint256 campaignId => string campaignURI) private _campaignURIs;

    /// @dev The total current redemptions by campaign id.
    mapping(uint256 campaignId => uint256 count) private _totalRedemptions;

    /// @dev The burn address.
    address constant _BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    function redeem(uint256[][] calldata tokenIds, address recipient, bytes calldata extraData)
        public
        payable
        virtual
        override
    {
        // Get the campaign id from extraData.
        uint256 campaignId = uint256(bytes32(extraData[0:32]));

        // Get the campaign params.
        CampaignParams storage params = _campaignParams[campaignId];

        // Validate the campaign time and total redemptions.
        _validateRedemption(params, numRedemptions);

        // Iterate over the token IDs for each redemption.
        uint256 numRedemptions = tokenIds.length;

        // Increment totalRedemptions.
        _totalRedemptions[campaignId] += numRedemptions;

        for (uint256 i; i < numRedemptions;) {
            _processRedemption(params, tokenIds[i]);

            unchecked {
                ++i;
            }
        }
    }

    function getCampaign(uint256 campaignId)
        external
        view
        override
        returns (CampaignParams memory params, string memory uri, uint256 totalRedemptions)
    {
        // Revert if campaign id is invalid.
        if (campaignId >= _nextCampaignId) revert InvalidCampaignId();

        // Get the campaign params.
        params = _campaignParams[campaignId];

        // Get the campaign URI.
        uri = _campaignURIs[campaignId];

        // Get the total redemptions.
        totalRedemptions = _totalRedemptions[campaignId];
    }

    function createCampaign(CampaignParams calldata params, string calldata uri)
        external
        override
        returns (uint256 campaignId)
    {
        // Validate the campaign params, reverts if invalid.
        _validateCampaignParams(params);

        // Determine the campaignId and increment the next one.
        uint256 campaignId = _nextCampaignId;
        ++_nextCampaignId;

        // Set the campaign params.
        _campaignParams[campaignId] = params;

        // Set the campaign URI.
        _campaignURIs[campaignId] = uri;

        emit CampaignUpdated(campaignId, params, uri);
    }

    function updateCampaign(uint256 campaignId, CampaignParams calldata params, string calldata uri)
        external
        override
    {
        // Revert if the campaign id is invalid.
        if (campaignId == 0 || campaignId >= _nextCampaignId) {
            revert InvalidCampaignId();
        }

        // Revert if msg.sender is not the manager.
        address existingManager = _campaignParams[campaignId].manager;
        if (params.manager != msg.sender && (existingManager != address(0) && existingManager != params.manager)) {
            revert NotManager();
        }

        // Validate the campaign params and revert if invalid.
        _validateCampaignParams(params);

        // Set the campaign params.
        _campaignParams[campaignId] = params;

        // Update the campaign uri if it was provided.
        if (bytes(uri).length != 0) {
            _campaignURIs[campaignId] = uri;
        }

        emit CampaignUpdated(campaignId, params, _campaignURIs[campaignId]);
    }

    function _validateCampaignParams() internal view {
        // Revert if startTime is past endTime.
        if (params.startTime > params.endTime) {
            revert InvalidTime();
        }

        // Keep track of the consideration items that have been seen,
        // to revert on duplicate.
        // Revert if there are any duplicate consideration items.

        for (uint256 i = 0; i < params.consideration.length;) {
            // Revert if any of the consideration item recipients is the zero address.
            // 0xdead address should be used instead.
            if (params.consideration[i].recipient == address(0)) {
                revert ConsiderationItemRecipientCannotBeZeroAddress(i);
            }

            if (params.consideration[i].startAmount == 0) {
                revert ConsiderationItemAmountCannotBeZero(i);
            }

            if (
                params.consideration[i].itemType == ItemType.ERC721
                    || params.consideration[i].itemType == ItemType.ERC721_WITH_CRITERIA
            ) {
                revert ConsiderationItemAmountMustBeOneForERC721(i);
            }

            // Revert if any startAmount != endAmount, as this requires more complex logic.
            if (params.consideration[i].startAmount != params.consideration[i].endAmount) {
                revert NonMatchingConsiderationItemAmounts(
                    i, params.consideration[i].startAmount, params.consideration[i].endAmount
                );
            }

            unchecked {
                ++i;
            }
        }
    }

    function _validateRedemption(CampaignParams params, uint256 numRedemptions) internal {
        if (_isInactive(params.startTime, params.endTime)) {
            revert NotActive_(block.timestamp, params.startTime, params.endTime);
        }

        // Revert if max total redemptions would be exceeded.
        if (_totalRedemptions[campaignId] + numRedemptions.length > params.maxCampaignRedemptions) {
            revert MaxCampaignRedemptionsReached(
                _totalRedemptions[campaignId] + numRedemptions.length, params.maxCampaignRedemptions
            );
        }
    }

    function _transferConsiderationItem(uint256 identifier, ConsiderationItem consideration) internal {
        // If consideration item is this contract, recipient is burn address, and _useInternalBurn() fn returns true,
        // call the internal burn function and return.
        if (
            consideration.token == address(this) && consideration.recipient == payable(_BURN_ADDRESS)
                && _useInternalBurn()
        ) {
            _internalBurn(identifier, consideration.startAmount);
            return;
        }

        // Transfer the token to the consideration recipient.
        if (consideration.itemType == ItemTypeERC721 || consideration.itemType == ERC721_WITH_CRITERIA) {
            IERC721(consideration.token).safeTransferFrom(msg.sender, consideration.recipient, identifier);
        } else if ((consideration.itemType == ItemType.ERC1155 || consideration.itemType == ERC1155_WITH_CRITERIA)) {
            IERC1155(consideration.token).safeTransferFrom(
                msg.sender, consideration.recipient, identifier, consideration.startAmount
            );
        } else if (considerationItem.itemType == ItemType.ERC20) {
            IERC20(consideration.token).transferFrom(msg.sender, consideration.recipient, consideration.startAmount);
        } else {
            // ItemType.NATIVE
            (bool success,) = consideration.recipient.call{value: msg.value}("");
            if (!success) revert EtherTransferFailed();
        }
    }

    /// @dev Override this function to return true if `_internalBurn` is used.
    function _useInternalBurn() internal view virtual returns (bool) {
        return false;
    }

    /// @dev Function that is called to burn amounts of a token internal to this inherited contract.
    ///      Override with token implementation calling internal burn.
    ///      Amount for IERC721 will always be 1.
    function _internalBurn(uint256 identifier, uint256 amount) internal virtual {}

    function _isInactive(uint256 startTime, uint256 endTime) internal view returns (bool inactive) {
        // Using the same check for time boundary from Seaport.
        // startTime <= block.timestamp < endTime
        assembly {
            inactive := or(iszero(gt(endTime, timestamp())), gt(startTime, timestamp()))
        }
    }

    function _processRedemption(CampaignParams memory params, uint256[] tokenIds) {
        // Get the campaign consideration.
        ConsiderationItem[] memory consideration = params.consideration;

        // Keep track of the total native value to validate.
        uint256 totalNativeValue;

        // Iterate over the consideration items.
        for (uint256 j; j < consideration.length;) {
            // Get the consideration item.
            ConsiderationItem memory c = params.consideration[i];

            // Get the identifier.
            uint256 id = ids[j];

            // Get the token balance.
            uint256 balance;
            if (c.itemType == ItemType.ERC721 || c.itemType == ItemType.ERC721_WITH_CRITERIA) {
                balance = IERC721(c.token).ownerOf(id) == msg.sender ? 1 : 0;
            } else if (c.itemType == ItemType.ERC1155 || c.itemType == ItemType.ERC1155_WITH_CRITERIA) {
                balance = IERC1155(c.token).balanceOf(msg.sender, id);
            } else if (consideration.itemType == ItemType.ERC20) {
                balance = IERC20(c.token).balanceOf(msg.sender);
            } else {
                // ItemType.NATIVE
                totalNativeValue += c.startAmount;
                // Total native value is validated after the loop.
            }

            // Ensure the balance is sufficient.
            if (balance < c.startAmount) {
                revert ConsiderationItemInsufficientBalance(c.token, balance, c.startAmount);
            }

            // Transfer the consideration item.
            _transferConsiderationItem(id, c);

            // Mint the new tokens.
            for (uint256 k; k < params.offer.length;) {
                IRedemptionMintable(params.offer[k].token).mintRedemption(campaignId, recipient, consideration);

                unchecked {
                    ++k;
                }
            }

            unchecked {
                ++j;
            }
        }

        // Validate the correct native value is sent with the transaction.
        if (msg.value != totalNativeValue * numRedemptions) {
            revert InvalidTxValue(msg.value, totalNativeValue * numRedemptions);
        }

        // Process trait redemptions.
        // _setTraits(traitRedemptions);
    }

    function _setTraits(TraitRedemption[] calldata traitRedemptions) internal {
        // Iterate over the trait redemptions and set traits on the tokens.
        for (uint256 i; i < traitRedemptions.length;) {
            // Get the trait redemption token address and place on the stack.
            address token = traitRedemptions[i].token;

            uint256 identifier = traitRedemptions[i].identifier;

            // Declare a new block to manage stack depth.
            {
                // Get the substandard and place on the stack.
                uint8 substandard = traitRedemptions[i].substandard;

                // Get the substandard value and place on the stack.
                bytes32 substandardValue = traitRedemptions[i].substandardValue;

                // Get the trait key and place on the stack.
                bytes32 traitKey = traitRedemptions[i].traitKey;

                bytes32 traitValue = traitRedemptions[i].traitValue;

                // Get the current trait value and place on the stack.
                bytes32 currentTraitValue = getTraitValue(traitKey, identifier);

                // If substandard is 1, set trait to traitValue.
                if (substandard == 1) {
                    // Revert if the current trait value does not match the substandard value.
                    if (currentTraitValue != substandardValue) {
                        revert InvalidRequiredValue(currentTraitValue, substandardValue);
                    }

                    // Set the trait to the trait value.
                    _setTrait(traitRedemptions[i].traitKey, identifier, traitValue);
                    // If substandard is 2, increment trait by traitValue.
                } else if (substandard == 2) {
                    // Revert if the current trait value is greater than the substandard value.
                    if (currentTraitValue > substandardValue) {
                        revert InvalidRequiredValue(currentTraitValue, substandardValue);
                    }

                    // Increment the trait by the trait value.
                    uint256 newTraitValue = uint256(currentTraitValue) + uint256(traitValue);

                    _setTrait(traitRedemptions[i].traitKey, identifier, bytes32(newTraitValue));
                } else if (substandard == 3) {
                    // Revert if the current trait value is less than the substandard value.
                    if (currentTraitValue < substandardValue) {
                        revert InvalidRequiredValue(currentTraitValue, substandardValue);
                    }

                    uint256 newTraitValue = uint256(currentTraitValue) - uint256(traitValue);

                    // Decrement the trait by the trait value.
                    _setTrait(traitRedemptions[i].traitKey, traitRedemptions[i].identifier, bytes32(newTraitValue));
                }
            }

            unchecked {
                ++i;
            }
        }
    }

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IERC7498).interfaceId;
    }
}

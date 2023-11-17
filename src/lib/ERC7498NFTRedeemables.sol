// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {IERC165} from "openzeppelin-contracts/contracts/interfaces/IERC165.sol";
import {IERC721} from "openzeppelin-contracts/contracts/interfaces/IERC721.sol";
import {IERC1155} from "openzeppelin-contracts/contracts/interfaces/IERC1155.sol";
import {ERC20Burnable} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC721Burnable} from "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {ERC1155Burnable} from "openzeppelin-contracts/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import {OfferItem, ConsiderationItem, SpentItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {ItemType} from "seaport-types/src/lib/ConsiderationEnums.sol";
import {DynamicTraits} from "shipyard-core/src/dynamic-traits/DynamicTraits.sol";
import {IERC7496} from "shipyard-core/src/dynamic-traits/interfaces/IERC7496.sol";
import {IERC7498} from "../interfaces/IERC7498.sol";
import {IRedemptionMintable} from "../interfaces/IRedemptionMintable.sol";
import {RedeemablesErrors} from "./RedeemablesErrors.sol";
import {Campaign, CampaignParams, CampaignRequirements, TraitRedemption} from "./RedeemablesStructs.sol";
import {BURN_ADDRESS} from "./RedeemablesConstants.sol";

contract ERC7498NFTRedeemables is IERC165, IERC7498, DynamicTraits, RedeemablesErrors {
    /// @dev Counter for next campaign id.
    uint256 private _nextCampaignId = 1;

    /// @dev The campaign by campaign id.
    mapping(uint256 campaignId => Campaign campaign) private _campaigns;

    /// @dev The campaign metadata URI.
    string private _campaignMetadataURI;

    /// @dev The total current redemptions by campaign id.
    mapping(uint256 campaignId => uint256 count) private _totalRedemptions;

    function redeem(uint256[] calldata considerationTokenIds, address recipient, bytes calldata extraData)
        public
        payable
    {
        // If the recipient is the null address, set to msg.sender.
        if (recipient == address(0)) {
            recipient = msg.sender;
        }

        // Get the values from extraData.
        (
            uint256 campaignId,
            uint256 requirementsIndex,
            /* bytes32 redemptionHash */
            ,
            uint256[] memory traitRedemptionTokenIds,
            /* uint256 salt */
            ,
            /*bytes memory signature */
        ) = abi.decode(extraData, (uint256, uint256, bytes32, uint256[], uint256, bytes));

        // Get the campaign.
        Campaign storage campaign = _campaigns[campaignId];

        // Validate the requirements index is valid.
        if (requirementsIndex >= campaign.requirements.length) {
            revert RequirementsIndexOutOfBounds();
        }

        // Validate the campaign time and total redemptions.
        _validateRedemption(campaignId, campaign);

        // Process the redemption.
        _processRedemption(
            campaignId,
            campaign.requirements[requirementsIndex],
            considerationTokenIds,
            traitRedemptionTokenIds,
            recipient
        );

        // Emit the Redemption event.
        emit Redemption(
            campaignId, requirementsIndex, bytes32(0), considerationTokenIds, traitRedemptionTokenIds, msg.sender
        );
    }

    function getCampaign(uint256 campaignId)
        public
        view
        override
        returns (Campaign memory campaign, string memory metadataURI, uint256 totalRedemptions)
    {
        // Revert if campaign id is invalid.
        if (campaignId == 0 || campaignId >= _nextCampaignId) {
            revert InvalidCampaignId();
        }

        // Get the campaign.
        campaign = _campaigns[campaignId];

        // Get the campaign metadata uri.
        metadataURI = _campaignMetadataURI;

        // Get the total redemptions.
        totalRedemptions = _totalRedemptions[campaignId];
    }

    /**
     * @notice Create a new redeemable campaign.
     * @dev    IMPORTANT: Override this method with access role restriction.
     * @param campaign The campaign.
     * @param metadataURI The campaign metadata uri.
     */
    function createCampaign(Campaign calldata campaign, string calldata metadataURI)
        public
        virtual
        returns (uint256 campaignId)
    {
        // Validate the campaign params, reverts if invalid.
        _validateCampaign(campaign);

        // Set the campaignId and increment the next one.
        campaignId = _nextCampaignId;
        ++_nextCampaignId;

        // Set the campaign params.
        _campaigns[campaignId] = campaign;

        // Set the campaign metadata uri if provided.
        if (bytes(metadataURI).length != 0) {
            _campaignMetadataURI = metadataURI;
        }

        emit CampaignUpdated(campaignId, campaign, _campaignMetadataURI);
    }

    function updateCampaign(uint256 campaignId, Campaign calldata campaign, string calldata metadataURI) external {
        // Revert if the campaign id is invalid.
        if (campaignId == 0 || campaignId >= _nextCampaignId) {
            revert InvalidCampaignId();
        }

        // Revert if msg.sender is not the manager.
        address existingManager = _campaigns[campaignId].params.manager;
        if (existingManager != msg.sender) {
            revert NotManager();
        }

        // Validate the campaign params and revert if invalid.
        _validateCampaign(campaign);

        // Set the campaign.
        _campaigns[campaignId] = campaign;

        // Update the campaign metadataURI if it was provided.
        if (bytes(metadataURI).length != 0) {
            _campaignMetadataURI = metadataURI;
        }

        emit CampaignUpdated(campaignId, campaign, _campaignMetadataURI);
    }

    function _validateCampaign(Campaign memory campaign) internal pure {
        // Revert if startTime is past endTime.
        if (campaign.params.startTime > campaign.params.endTime) {
            revert InvalidTime();
        }

        // Iterate over the requirements.
        for (uint256 i; i < campaign.requirements.length;) {
            CampaignRequirements memory requirement = campaign.requirements[i];

            // Validate each consideration item.
            for (uint256 j = 0; j < requirement.consideration.length;) {
                ConsiderationItem memory c = requirement.consideration[j];

                // Revert if any of the consideration item recipients is the zero address.
                // 0xdead address should be used instead.
                // For internal burn, override _internalBurn and set _useInternalBurn to true.
                if (c.recipient == address(0)) {
                    revert ConsiderationItemRecipientCannotBeZeroAddress();
                }

                if (c.startAmount == 0) {
                    revert ConsiderationItemAmountCannotBeZero();
                }

                // Revert if startAmount != endAmount, as this requires more complex logic.
                if (c.startAmount != c.endAmount) {
                    revert NonMatchingConsiderationItemAmounts(i, c.startAmount, c.endAmount);
                }
                unchecked {
                    ++j;
                }
            }
            unchecked {
                ++i;
            }
        }
    }

    function _validateRedemption(uint256 campaignId, Campaign storage campaign) internal view {
        if (_isInactive(campaign.params.startTime, campaign.params.endTime)) {
            revert NotActive_(block.timestamp, campaign.params.startTime, campaign.params.endTime);
        }

        // Revert if max total redemptions would be exceeded.
        if (_totalRedemptions[campaignId] + 1 > campaign.params.maxCampaignRedemptions) {
            revert MaxCampaignRedemptionsReached(
                _totalRedemptions[campaignId] + 1, campaign.params.maxCampaignRedemptions
            );
        }
    }

    function _transferConsiderationItem(uint256 id, ConsiderationItem memory c) internal {
        // WITH_CRITERIA with identifier 0 is wildcard: any id is valid.
        // Criteria is not yet implemented, for that functionality use the contract offerer.
        if (
            id != c.identifierOrCriteria && c.identifierOrCriteria != 0
                && (c.itemType != ItemType.ERC721_WITH_CRITERIA || c.itemType != ItemType.ERC1155_WITH_CRITERIA)
        ) {
            revert InvalidConsiderationTokenIdSupplied(c.token, id, c.identifierOrCriteria);
        }

        // If consideration item is this contract, recipient is burn address, and _useInternalBurn() fn returns true,
        // call the internal burn function and return.
        if (c.token == address(this) && c.recipient == payable(BURN_ADDRESS) && _useInternalBurn()) {
            _internalBurn(msg.sender, id, c.startAmount);
        } else {
            // Transfer the token to the consideration recipient.
            if (c.itemType == ItemType.ERC721 || c.itemType == ItemType.ERC721_WITH_CRITERIA) {
                // If recipient is the burn address, try burning the token first, if that doesn't work use transfer.
                if (c.recipient == payable(BURN_ADDRESS)) {
                    try ERC721Burnable(c.token).burn(id) {
                        // If the burn worked, return.
                        return;
                    } catch {
                        // If the burn failed, transfer the token.
                        IERC721(c.token).safeTransferFrom(msg.sender, c.recipient, id);
                    }
                } else {
                    IERC721(c.token).safeTransferFrom(msg.sender, c.recipient, id);
                }
            } else if ((c.itemType == ItemType.ERC1155 || c.itemType == ItemType.ERC1155_WITH_CRITERIA)) {
                if (c.recipient == payable(BURN_ADDRESS)) {
                    // If recipient is the burn address, try burning the token first, if that doesn't work use transfer.
                    try ERC1155Burnable(c.token).burn(msg.sender, id, c.startAmount) {
                        // If the burn worked, return.
                        return;
                    } catch {
                        // If the burn failed, transfer the token.
                        IERC1155(c.token).safeTransferFrom(msg.sender, c.recipient, id, c.startAmount, "");
                    }
                } else {
                    IERC1155(c.token).safeTransferFrom(msg.sender, c.recipient, id, c.startAmount, "");
                }
            } else if (c.itemType == ItemType.ERC20) {
                if (c.recipient == payable(BURN_ADDRESS)) {
                    // If recipient is the burn address, try burning the token first, if that doesn't work use transfer.
                    try ERC20Burnable(c.token).burnFrom(msg.sender, c.startAmount) {
                        // If the burn worked, return.
                        return;
                    } catch {
                        // If the burn failed, transfer the token.
                        IERC20(c.token).transferFrom(msg.sender, c.recipient, c.startAmount);
                    }
                } else {
                    IERC20(c.token).transferFrom(msg.sender, c.recipient, c.startAmount);
                }
            } else {
                // ItemType.NATIVE
                (bool success,) = c.recipient.call{value: msg.value}("");
                if (!success) revert EtherTransferFailed();
            }
        }
    }

    /// @dev Override this function to return true if `_internalBurn` is used.
    function _useInternalBurn() internal pure virtual returns (bool) {
        return false;
    }

    /// @dev Function that is called to burn amounts of a token internal to this inherited contract.
    ///      Override with token implementation calling internal burn.
    function _internalBurn(address from, uint256 id, uint256 amount) internal virtual {
        // Override with your token implementation calling internal burn.
    }

    function _isInactive(uint256 startTime, uint256 endTime) internal view returns (bool inactive) {
        // Using the same check for time boundary from Seaport.
        // startTime <= block.timestamp < endTime
        assembly {
            inactive := or(iszero(gt(endTime, timestamp())), gt(startTime, timestamp()))
        }
    }

    function _processRedemption(
        uint256 campaignId,
        CampaignRequirements memory requirements,
        uint256[] memory considerationTokenIds,
        uint256[] memory traitRedemptionTokenIds,
        address recipient
    ) internal {
        // Increment the campaign's total redemptions.
        ++_totalRedemptions[campaignId];

        if (requirements.traitRedemptions.length > 0) {
            // Process the trait redemptions.
            _processTraitRedemptions(requirements.traitRedemptions, traitRedemptionTokenIds);
        }

        if (requirements.consideration.length > 0) {
            // Process the consideration items.
            _processConsiderationItems(requirements.consideration, considerationTokenIds);
        }

        if (requirements.offer.length > 0) {
            // Process the offer items.
            _processOfferItems(
                campaignId, requirements.consideration, requirements.offer, requirements.traitRedemptions, recipient
            );
        }
    }

    function _processConsiderationItems(
        ConsiderationItem[] memory consideration,
        uint256[] memory considerationTokenIds
    ) internal {
        // Revert if the tokenIds length does not match the consideration length.
        if (consideration.length != considerationTokenIds.length) {
            revert ConsiderationTokenIdsDontMatchConsiderationLength(consideration.length, considerationTokenIds.length);
        }

        // Keep track of the total native value to validate.
        uint256 totalNativeValue;

        // Iterate over the consideration items.
        for (uint256 i; i < consideration.length;) {
            // Get the consideration item.
            ConsiderationItem memory c = consideration[i];

            // Get the identifier.
            uint256 id = considerationTokenIds[i];

            // Get the token balance.
            uint256 balance;
            if (c.itemType == ItemType.ERC721 || c.itemType == ItemType.ERC721_WITH_CRITERIA) {
                balance = IERC721(c.token).ownerOf(id) == msg.sender ? 1 : 0;
            } else if (c.itemType == ItemType.ERC1155 || c.itemType == ItemType.ERC1155_WITH_CRITERIA) {
                balance = IERC1155(c.token).balanceOf(msg.sender, id);
            } else if (c.itemType == ItemType.ERC20) {
                balance = IERC20(c.token).balanceOf(msg.sender);
            } else {
                // ItemType.NATIVE
                totalNativeValue += c.startAmount;
                // Total native value is validated after the loop.
            }

            // Ensure the balance is sufficient.
            if (c.itemType != ItemType.NATIVE && balance < c.startAmount) {
                revert ConsiderationItemInsufficientBalance(c.token, balance, c.startAmount);
            }

            // Transfer the consideration item.
            _transferConsiderationItem(id, c);

            unchecked {
                ++i;
            }
        }

        // Validate the correct native value is sent with the transaction.
        if (msg.value != totalNativeValue) {
            revert InvalidTxValue(msg.value, totalNativeValue);
        }
    }

    function _processTraitRedemptions(
        TraitRedemption[] memory traitRedemptions,
        uint256[] memory traitRedemptionTokenIds
    ) internal {
        if (traitRedemptions.length != traitRedemptionTokenIds.length) {
            revert TraitRedemptionTokenIdsDontMatchTraitRedemptionsLength(
                traitRedemptions.length, traitRedemptionTokenIds.length
            );
        }

        _setTraits(traitRedemptions, traitRedemptionTokenIds);
    }

    function _processOfferItems(
        uint256 campaignId,
        ConsiderationItem[] memory consideration,
        OfferItem[] memory offer,
        TraitRedemption[] memory traitRedemptions,
        address recipient
    ) internal {
        // Mint the new tokens.
        for (uint256 i; i < offer.length;) {
            OfferItem memory offerItem = offer[i];
            IRedemptionMintable(offerItem.token).mintRedemption(
                campaignId, recipient, offerItem, consideration, traitRedemptions
            );
            unchecked {
                ++i;
            }
        }
    }

    function _setTraits(TraitRedemption[] memory traitRedemptions, uint256[] memory traitRedemptionTokenIds) internal {
        // Iterate over the trait redemptions and set traits on the tokens.
        for (uint256 i; i < traitRedemptions.length;) {
            // Get the trait redemption identifier and place on the stack.
            uint256 identifier = traitRedemptionTokenIds[i];

            // Declare a new block to manage stack depth.
            {
                // Get the substandard and place on the stack.
                uint8 substandard = traitRedemptions[i].substandard;

                // Get the substandard value and place on the stack.
                bytes32 substandardValue = traitRedemptions[i].substandardValue;

                // Get the token and place on the stack.
                address token = traitRedemptions[i].token;

                // Get the trait key and place on the stack.
                bytes32 traitKey = traitRedemptions[i].traitKey;

                // Get the trait value and place on the stack.
                bytes32 traitValue = traitRedemptions[i].traitValue;

                // Get the current trait value and place on the stack.
                bytes32 currentTraitValue = IERC7496(token).getTraitValue(identifier, traitKey);

                // If substandard is 1, set trait to traitValue.
                if (substandard == 1) {
                    // Revert if the current trait value does not match the substandard value.
                    if (currentTraitValue != substandardValue) {
                        revert InvalidRequiredTraitValue(
                            token, identifier, traitKey, currentTraitValue, substandardValue
                        );
                    }

                    // Set the trait to the trait value.
                    IERC7496(token).setTrait(identifier, traitRedemptions[i].traitKey, traitValue);
                    // If substandard is 2, increment trait by traitValue.
                } else if (substandard == 2) {
                    // Revert if the current trait value is greater than the substandard value.
                    if (currentTraitValue > substandardValue) {
                        revert InvalidRequiredTraitValue(
                            token, identifier, traitKey, currentTraitValue, substandardValue
                        );
                    }

                    // Increment the trait by the trait value.
                    uint256 newTraitValue = uint256(currentTraitValue) + uint256(traitValue);

                    IERC7496(token).setTrait(identifier, traitRedemptions[i].traitKey, bytes32(newTraitValue));
                } else if (substandard == 3) {
                    // Revert if the current trait value is less than the substandard value.
                    if (currentTraitValue < substandardValue) {
                        revert InvalidRequiredTraitValue(
                            token, identifier, traitKey, currentTraitValue, substandardValue
                        );
                    }

                    uint256 newTraitValue = uint256(currentTraitValue) - uint256(traitValue);

                    // Decrement the trait by the trait value.
                    IERC7496(token).setTrait(identifier, traitRedemptions[i].traitKey, bytes32(newTraitValue));
                } else if (substandard == 4) {
                    // Revert if the current trait value is not equal to the trait value.
                    if (currentTraitValue != traitValue) {
                        revert InvalidRequiredTraitValue(
                            token, identifier, traitKey, currentTraitValue, substandardValue
                        );
                    }
                    // No-op: substandard 4 has no set trait action.
                }
            }

            unchecked {
                ++i;
            }
        }
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(IERC165, DynamicTraits)
        returns (bool)
    {
        return interfaceId == type(IERC7498).interfaceId || interfaceId == type(IERC165).interfaceId
            || interfaceId == type(IERC7496).interfaceId;
    }
}

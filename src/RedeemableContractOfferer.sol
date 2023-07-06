// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ContractOffererInterface} from "seaport-types/src/interfaces/ContractOffererInterface.sol";
import {ItemType} from "seaport-types/src/lib/ConsiderationEnums.sol";
import {
    OfferItem,
    ConsiderationItem,
    ReceivedItem,
    Schema,
    SpentItem
} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {ERC721} from "solady/src/tokens/ERC721.sol";
import {ERC1155} from "solady/src/tokens/ERC1155.sol";
import {IERC721Receiver} from "seaport-types/src/interfaces/IERC721Receiver.sol";
import {IERC1155Receiver} from "./interfaces/IERC1155Receiver.sol";
import {IERC721RedemptionMintable} from "./interfaces/IERC721RedemptionMintable.sol";
import {IERC1155RedemptionMintable} from "./interfaces/IERC1155RedemptionMintable.sol";
import {SignedRedeemContractOfferer} from "./lib/SignedRedeemContractOfferer.sol";
import {RedeemableErrorsAndEvents} from "./lib/RedeemableErrorsAndEvents.sol";
import {CampaignParams} from "./lib/RedeemableStructs.sol";

/**
 * @title  RedeemablesContractOfferer
 * @author ryanio
 * @notice A Seaport contract offerer that allows users to burn to redeem off chain redeemables.
 */
contract RedeemableContractOfferer is
    ContractOffererInterface,
    RedeemableErrorsAndEvents,
    SignedRedeemContractOfferer
{
    /// @dev The Seaport address allowed to interact with this contract offerer.
    address internal immutable _SEAPORT;

    /// @dev The conduit address to allow as an operator for this contract for newly minted tokens.
    address internal immutable _CONDUIT;

    /// @dev Counter for next campaign id.
    uint256 private _nextCampaignId = 1;

    /// @dev The campaign parameters by campaign id.
    mapping(uint256 campaignId => CampaignParams params) private _campaignParams;

    /// @dev The campaign URIs by campaign id.
    mapping(uint256 campaignId => string campaignURI) private _campaignURIs;

    /// @dev The total current redemptions by campaign id.
    mapping(uint256 campaignId => uint256 count) private _totalRedemptions;

    constructor(address conduit, address seaport) {
        _CONDUIT = conduit;
        _SEAPORT = seaport;
    }

    function updateCampaign(uint256 campaignId, CampaignParams calldata params, string calldata uri) external {
        if (campaignId >= _nextCampaignId) revert InvalidCampaignId();

        if (campaignId == 0) {
            campaignId = _nextCampaignId;
            unchecked {
                ++_nextCampaignId;
            }
        }

        // Revert if there are no consideration items, since the redemption should require at least something.
        if (params.consideration.length == 0) revert NoConsiderationItems();

        // Revert if startTime is past endTime.
        if (params.startTime > params.endTime) revert InvalidTime();

        // Revert if msg.sender is not the manager.
        address existingManager = _campaignParams[campaignId].manager;
        if (params.manager != msg.sender && (existingManager != address(0) && existingManager != params.manager)) {
            revert NotManager();
        }

        // Revert if any of the consideration item recipients is the zero address. The 0xdead address should be used instead.
        for (uint256 i = 0; i < params.consideration.length;) {
            if (params.consideration[i].recipient == address(0)) revert ConsiderationItemRecipientCannotBeZeroAddress();
            unchecked {
                ++i;
            }
        }

        // Allow Seaport and the conduit as operators on behalf of this contract for offer items to be minted and transferred.
        for (uint256 i = 0; i < params.offer.length;) {
            // ERC721 and ERC1155 have the same function signatures for isApprovedForAll and setApprovalForAll.
            if (!ERC721(params.offer[i].token).isApprovedForAll(_SEAPORT, address(this))) {
                ERC721(params.offer[i].token).setApprovalForAll(_SEAPORT, true);
            }
            if (!ERC721(params.offer[i].token).isApprovedForAll(_CONDUIT, address(this))) {
                ERC721(params.offer[i].token).setApprovalForAll(_CONDUIT, true);
            }
            unchecked {
                ++i;
            }
        }

        _campaignParams[campaignId] = params;

        // Update campaign uri if it was provided.
        if (bytes(uri).length != 0) {
            _campaignURIs[campaignId] = uri;
        }

        emit CampaignUpdated(campaignId, params, _campaignURIs[campaignId]);
    }

    function updateCampaignURI(uint256 campaignId, string calldata uri) external {
        CampaignParams storage params = _campaignParams[campaignId];

        if (params.manager != msg.sender) revert NotManager();

        _campaignURIs[campaignId] = uri;

        emit CampaignUpdated(campaignId, params, uri);
    }

    /**
     * @dev Generates an order with the specified minimum and maximum spent
     *      items, and optional context (supplied as extraData).
     *
     * @param fulfiller        The address of the fulfiller.
     * @param minimumReceived  The minimum items that the caller must receive.
     * @param maximumSpent     The maximum items the caller is willing to spend.
     * @param context          Additional context of the order.
     *
     * @return offer         A tuple containing the offer items.
     * @return consideration An array containing the consideration items.
     */
    function generateOrder(
        address fulfiller,
        SpentItem[] calldata minimumReceived,
        SpentItem[] calldata maximumSpent,
        bytes calldata context // encoded based on the schemaID
    ) external override returns (SpentItem[] memory offer, ReceivedItem[] memory consideration) {
        // Derive the offer and consideration with effects.
        (offer, consideration) = _createOrder(fulfiller, minimumReceived, maximumSpent, context, true);
    }

    /**
     * @dev Ratifies an order with the specified offer, consideration, and
     *      optional context (supplied as extraData).
     *
     * @custom:param offer         The offer items.
     * @custom:param consideration The consideration items.
     * @custom:param context       Additional context of the order.
     * @custom:param orderHashes   The hashes to ratify.
     * @custom:param contractNonce The nonce of the contract.
     *
     * @return ratifyOrderMagicValue The magic value returned by the contract
     *                               offerer.
     */
    function ratifyOrder(
        SpentItem[] calldata, /* offer */
        ReceivedItem[] calldata, /* consideration */
        bytes calldata, /* context */ // encoded based on the schemaID
        bytes32[] calldata, /* orderHashes */
        uint256 /* contractNonce */
    ) external pure override returns (bytes4) {
        assembly {
            // Return the RatifyOrder magic value.
            mstore(0, 0xf4dd92ce)
            return(0x1c, 32)
        }
    }

    /**
     * @dev View function to preview an order generated in response to a minimum
     *      set of received items, maximum set of spent items, and context
     *      (supplied as extraData).
     *
     * @custom:param caller      The address of the caller (e.g. Seaport).
     * @param fulfiller          The address of the fulfiller (e.g. the account
     *                           calling Seaport).
     * @param minimumReceived    The minimum items that the caller is willing to
     *                           receive.
     * @param maximumSpent       The maximum items caller is willing to spend.
     * @param context            Additional context of the order.
     *
     * @return offer         A tuple containing the offer items.
     * @return consideration A tuple containing the consideration items.
     */
    function previewOrder(
        address, /* caller */
        address fulfiller,
        SpentItem[] calldata minimumReceived,
        SpentItem[] calldata maximumSpent,
        bytes calldata context // encoded based on the schemaID
    ) external view override returns (SpentItem[] memory offer, ReceivedItem[] memory consideration) {
        // To avoid the solidity compiler complaining about calling a non-view
        // function here (_createOrder), we will cast it as a view and use it.
        // This is okay because we are not modifying any state when passing
        // withEffects=false.
        function(
            address,
            SpentItem[] memory,
            SpentItem[] memory,
            bytes calldata,
            bool
        ) internal view returns (SpentItem[] memory, ReceivedItem[] memory) fn;
        function(
            address,
            SpentItem[] memory,
            SpentItem[] memory,
            bytes calldata,
            bool
        )
            internal
            returns (
                SpentItem[] memory,
                ReceivedItem[] memory
            ) fn2 = _createOrder;
        assembly {
            fn := fn2
        }

        // Derive the offer and consideration without effects.
        (offer, consideration) = fn(fulfiller, minimumReceived, maximumSpent, context, false);
    }

    /**
     * @dev Gets the metadata for this contract offerer.
     *
     * @return name    The name of the contract offerer.
     * @return schemas The schemas supported by the contract offerer.
     */
    function getSeaportMetadata()
        external
        pure
        override
        returns (
            string memory name,
            Schema[] memory schemas // map to Seaport Improvement Proposal IDs
        )
    {
        schemas = new Schema[](0);
        return ("RedeemablesContractOfferer", schemas);
    }

    function supportsInterface(bytes4 interfaceId) external view virtual returns (bool) {
        return interfaceId == type(ContractOffererInterface).interfaceId
            || interfaceId == type(IERC721Receiver).interfaceId || interfaceId == type(IERC1155Receiver).interfaceId;
    }

    function _createOrder(
        address fulfiller,
        SpentItem[] memory minimumReceived,
        SpentItem[] memory maximumSpent,
        bytes calldata context,
        bool withEffects
    ) internal returns (SpentItem[] memory offer, ReceivedItem[] memory consideration) {
        // Get the campaign.
        uint256 campaignId = uint256(bytes32(context[0:32]));
        CampaignParams storage params = _campaignParams[campaignId];

        // Declare an error buffer; first check is that caller is Seaport or the token contract.
        uint256 errorBuffer = _cast(msg.sender != _SEAPORT && msg.sender != params.consideration[0].token);

        // Check the redemption is active.
        errorBuffer |= _cast(_isInactive(params.startTime, params.endTime)) << 2;

        // Check max total redemptions would not be exceeded.
        errorBuffer |= _cast(_totalRedemptions[campaignId] + maximumSpent.length > params.maxTotalRedemptions) << 3;

        // Get the redemption hash.
        bytes32 redemptionHash = bytes32(context[32:64]);

        // Check the signature is valid if required.
        if (params.signer != address(0)) {
            uint256 salt = uint256(bytes32(context[64:96]));
            bytes memory signature = context[96:];
            // _verifySignature will revert if the signature is invalid or digest is already used.
            _verifySignature(params.signer, fulfiller, maximumSpent, redemptionHash, salt, signature, withEffects);
        }

        if (errorBuffer > 0) {
            if (errorBuffer << 255 != 0) {
                revert InvalidCaller(msg.sender);
            } else if (errorBuffer << 254 != 0) {
                revert NotActive(block.timestamp, params.startTime, params.endTime);
            } else if (errorBuffer << 253 != 0) {
                revert MaxTotalRedemptionsReached(
                    _totalRedemptions[campaignId] + maximumSpent.length, params.maxTotalRedemptions
                );
            } else if (errorBuffer << 252 != 0) {
                revert InvalidConsiderationLength(maximumSpent.length, params.consideration.length);
            } else if (errorBuffer << 251 != 0) {
                revert InvalidConsiderationItem(maximumSpent[0].token, params.consideration[0].token);
            } else if (errorBuffer << 251 != 0) {
                revert InvalidOfferLength(minimumReceived.length, params.offer.length);
            } else {
                // todo more validation errors
            }
        }

        // If withEffects is true then make state changes.
        if (withEffects) {
            // Increment total redemptions.
            _totalRedemptions[campaignId] += maximumSpent.length;

            // Emit Redemption event.
            emit Redemption(fulfiller, campaignId, maximumSpent, minimumReceived, redemptionHash);
        }

        // Set the offer from the params.
        offer = new SpentItem[](params.offer.length);
        for (uint256 i = 0; i < params.offer.length;) {
            OfferItem memory offerItem = params.offer[i];
            offer[i] = SpentItem({
                itemType: offerItem.itemType,
                token: offerItem.token,
                identifier: offerItem.identifierOrCriteria,
                amount: offerItem.startAmount
            });
            // If withEffects=true, call mint on the offer items.
            if (withEffects) {
                if (offerItem.itemType == ItemType.ERC721) {
                    IERC721RedemptionMintable(offerItem.token).mintRedemption(address(this), maximumSpent);
                } else if (offerItem.itemType == ItemType.ERC1155) {
                    IERC1155RedemptionMintable(offerItem.token).mintRedemption(address(this), maximumSpent);
                }
            }
            unchecked {
                ++i;
            }
        }

        // Set the consideration from the params.
        consideration = new ReceivedItem[](params.consideration.length);
        for (uint256 i = 0; i < params.consideration.length;) {
            ConsiderationItem memory considerationItem = params.consideration[i];
            consideration[i] = ReceivedItem({
                itemType: considerationItem.itemType,
                token: considerationItem.token,
                identifier: considerationItem.identifierOrCriteria,
                amount: considerationItem.startAmount,
                recipient: considerationItem.recipient
            });
            unchecked {
                ++i;
            }
        }
    }

    function onERC721Received(address, /* operator */ address from, uint256 tokenId, bytes calldata data)
        external
        returns (bytes4)
    {
        // Get the campaign.
        uint256 campaignId = uint256(bytes32(data[0:32]));
        CampaignParams storage params = _campaignParams[campaignId];

        SpentItem[] memory minimumReceived = new SpentItem[](1);
        minimumReceived[0] = SpentItem({
            itemType: ItemType.ERC721,
            token: params.offer[0].token,
            identifier: params.offer[0].identifierOrCriteria,
            amount: params.offer[0].startAmount
        });

        SpentItem[] memory maximumSpent = new SpentItem[](1);
        maximumSpent[0] = SpentItem({itemType: ItemType.ERC721, token: msg.sender, identifier: tokenId, amount: 1});

        // _createOrder will revert if any validations fail.
        _createOrder(from, minimumReceived, maximumSpent, data, true);

        // Transfer the redeemable token to the consideration item recipient.
        address recipient = _getConsiderationRecipient(params.consideration, msg.sender);
        ERC721(msg.sender).safeTransferFrom(address(this), payable(recipient), tokenId);

        // Transfer the newly minted token to the fulfiller.
        ERC721(params.offer[0].token).safeTransferFrom(address(this), from, tokenId);

        return IERC721Receiver.onERC721Received.selector;
    }

    function onERC1155Received(address, /* operator */ address from, uint256 id, uint256 value, bytes calldata data)
        external
        returns (bytes4)
    {
        // Get the campaign.
        uint256 campaignId = uint256(bytes32(data[0:32]));
        CampaignParams storage params = _campaignParams[campaignId];

        SpentItem[] memory minimumReceived = new SpentItem[](1);
        minimumReceived[0] = SpentItem({
            itemType: ItemType.ERC721,
            token: params.offer[0].token,
            identifier: params.offer[0].identifierOrCriteria,
            amount: params.offer[0].startAmount
        });

        SpentItem[] memory maximumSpent = new SpentItem[](1);
        maximumSpent[0] = SpentItem({itemType: ItemType.ERC1155, token: msg.sender, identifier: id, amount: value});

        // _createOrder will revert if any validations fail.
        _createOrder(from, minimumReceived, maximumSpent, data, true);

        // Transfer the token to the consideration item recipient.
        address recipient = _getConsiderationRecipient(params.consideration, msg.sender);
        ERC1155(msg.sender).safeTransferFrom(address(this), recipient, id, value, "");

        // Transfer the newly minted token to the fulfiller.
        ERC721(params.offer[0].token).safeTransferFrom(address(this), from, id, "");

        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address, /* operator */
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4) {
        if (ids.length != values.length) revert RedeemMismatchedLengths();

        // Get the campaign.
        uint256 campaignId = uint256(bytes32(data[0:32]));
        CampaignParams storage params = _campaignParams[campaignId];

        SpentItem[] memory minimumReceived = new SpentItem[](1);
        minimumReceived[0] = SpentItem({
            itemType: ItemType.ERC721,
            token: params.offer[0].token,
            identifier: params.offer[0].identifierOrCriteria,
            amount: params.offer[0].startAmount
        });

        SpentItem[] memory maximumSpent = new SpentItem[](ids.length);
        for (uint256 i = 0; i < ids.length;) {
            maximumSpent[i] =
                SpentItem({itemType: ItemType.ERC1155, token: msg.sender, identifier: ids[i], amount: values[i]});
            unchecked {
                ++i;
            }
        }

        // _createOrder will revert if any validations fail.
        _createOrder(from, minimumReceived, maximumSpent, data, true);

        // Transfer the tokens to the consideration item recipient.
        address recipient = _getConsiderationRecipient(params.consideration, msg.sender);
        ERC1155(msg.sender).safeBatchTransferFrom(address(this), recipient, ids, values, "");

        // Transfer the newly minted token to the fulfiller.
        ERC721(params.offer[0].token).safeTransferFrom(address(this), from, ids[0]);

        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    function getCampaign(uint256 campaignId)
        external
        view
        returns (CampaignParams memory params, string memory uri, uint256 totalRedemptions)
    {
        params = _campaignParams[campaignId];
        uri = _campaignURIs[campaignId];
        totalRedemptions = _totalRedemptions[campaignId];
    }

    function _getConsiderationRecipient(ConsiderationItem[] storage consideration, address token)
        internal
        view
        returns (address)
    {
        for (uint256 i = 0; i < consideration.length;) {
            if (consideration[i].token == token) {
                return consideration[i].recipient;
            }
            unchecked {
                ++i;
            }
        }
        revert ConsiderationRecipientNotFound(token);
    }

    function _isInactive(uint256 startTime, uint256 endTime) internal view returns (bool inactive) {
        // Using the same check for time boundary from Seaport.
        // startTime <= block.timestamp < endTime
        assembly {
            inactive := or(iszero(gt(endTime, timestamp())), gt(startTime, timestamp()))
        }
    }

    function _isValidTokenAddress(CampaignParams memory params, address token) internal pure returns (bool valid) {
        for (uint256 i = 0; i < params.consideration.length;) {
            if (params.consideration[i].token == token) {
                valid = true;
                break;
            }
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Internal utility function to remove a uint from a supplied
     *         enumeration.
     *
     * @param toRemove    The uint to remove.
     * @param enumeration The enumerated uints to parse.
     */
    function _removeFromEnumeration(uint256 toRemove, uint256[] storage enumeration) internal {
        // Cache the length.
        uint256 enumerationLength = enumeration.length;
        for (uint256 i = 0; i < enumerationLength;) {
            // Check if the enumerated element is the one we are deleting.
            if (enumeration[i] == toRemove) {
                // Swap with the last element.
                enumeration[i] = enumeration[enumerationLength - 1];
                // Delete the (now duplicated) last element.
                enumeration.pop();
                // Exit the loop.
                break;
            }
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Internal utility function to cast uint types to address
     *         to dedupe the need for multiple implementations of
     *         `_removeFromEnumeration`.
     *
     * @param fnIn The fn with uint input.
     *
     * @return fnOut The fn with address input.
     */
    function _asAddressArray(function(uint256, uint256[] storage) internal fnIn)
        internal
        pure
        returns (function(address, address[] storage) internal fnOut)
    {
        assembly {
            fnOut := fnIn
        }
    }

    /**
     * @dev Internal pure function to cast a `bool` value to a `uint256` value.
     *
     * @param b The `bool` value to cast.
     *
     * @return u The `uint256` value.
     */
    function _cast(bool b) internal pure returns (uint256 u) {
        assembly {
            u := b
        }
    }
}

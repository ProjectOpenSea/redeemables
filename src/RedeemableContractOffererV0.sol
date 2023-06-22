// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ContractOffererInterface} from "seaport-types/src/interfaces/ContractOffererInterface.sol";
import {ItemType} from "seaport-types/src/lib/ConsiderationEnums.sol";
import {OfferItem, ConsiderationItem, ReceivedItem, Schema, SpentItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {IERC721} from "forge-std/interfaces/IERC721.sol";
import {IERC1155} from "forge-std/interfaces/IERC1155.sol";
import {IERC721Receiver} from "seaport-types/src/interfaces/IERC721Receiver.sol";
import {IERC1155Receiver} from "./interfaces/IERC1155Receiver.sol";
import {RedeemableErrorsAndEvents} from "./lib/RedeemableErrorsAndEvents.sol";
import {RedeemableRegistryParamsV0} from "./lib/RedeemableStructs.sol";

/**
 * @title  RedeemablesContractOffererV0
 * @author ryanio
 * @notice A Seaport contract offerer that allows users to burn to redeem off chain redeemables.
 */
contract RedeemableContractOffererV0 is
    ContractOffererInterface,
    RedeemableErrorsAndEvents
{
    /// @dev The Seaport address allowed to interact with this contract offerer.
    address internal immutable _SEAPORT;

    /// @dev The default burn address.
    address constant _DEFAULT_BURN_ADDRESS =
        0x000000000000000000000000000000000000dEaD;

    /// @dev The redeemable parameters by their hash.
    mapping(bytes32 paramsHash => RedeemableRegistryParamsV0 params)
        private _redeemableParams;

    /// @dev The redeemable URIs by params hash.
    mapping(bytes32 paramsHash => string redeemableURI) private _redeemableURIs;

    /// @dev The total current redemptions by params hash.
    mapping(bytes32 paramsHash => uint256 count) _totalRedemptions;

    constructor(address seaport) {
        _SEAPORT = seaport;
    }

    function updateRedeemableParams(
        bytes32 paramsHash,
        RedeemableRegistryParamsV0 calldata params,
        string calldata uri
    ) external {
        if (paramsHash == bytes32(0))
            paramsHash = _getRedeemableParamsHash(params);

        if (params.offer.length != 0) revert OfferItemsNotAllowed();
        if (params.consideration.length == 0) revert NoConsiderationItems();

        RedeemableRegistryParamsV0 storage existingParams = _redeemableParams[
            paramsHash
        ];

        if (
            params.registeredBy != msg.sender ||
            (existingParams.registeredBy != address(0) &&
                existingParams.registeredBy != msg.sender)
        ) revert NotOwnerOrAllowed();

        if (existingParams.redemptionSettingsAreImmutable)
            revert RedemptionSettingsAreImmutable();

        _redeemableParams[paramsHash] = params;

        // Since params is calldata we cannot modify it, so we set sendTo after if needed.
        if (params.sendTo == address(0)) {
             _redeemableParams[paramsHash].sendTo = _DEFAULT_BURN_ADDRESS;
        }

        emit RedeemableParamsUpdated(paramsHash, params);

        if (bytes(uri).length != 0) {
            _redeemableURIs[paramsHash] = uri;
            emit RedeemableURIUpdated(paramsHash, uri);
        }
    }

    function updateRedeemableURI(
        bytes32 redeemableParamsHash,
        string calldata uri
    ) external {
        RedeemableRegistryParamsV0 storage params = _redeemableParams[
            redeemableParamsHash
        ];

        if (params.registeredBy != msg.sender) revert NotOwnerOrAllowed();

        _redeemableURIs[redeemableParamsHash] = uri;
        emit RedeemableURIUpdated(redeemableParamsHash, uri);
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
    )
        external
        override
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    {
        // Derive the offer and consideration with effects.
        (offer, consideration) = _createOrder(
            fulfiller,
            minimumReceived,
            maximumSpent,
            context,
            true
        );
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
        SpentItem[] calldata /* offer */,
        ReceivedItem[] calldata /* consideration */,
        bytes calldata /* context */, // encoded based on the schemaID
        bytes32[] calldata /* orderHashes */,
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
        address /* caller */,
        address fulfiller,
        SpentItem[] calldata minimumReceived,
        SpentItem[] calldata maximumSpent,
        bytes calldata context // encoded based on the schemaID
    )
        external
        view
        override
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    {
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
        (offer, consideration) = fn(
            fulfiller,
            minimumReceived,
            maximumSpent,
            context,
            false
        );
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

    function supportsInterface(
        bytes4 interfaceId
    ) external view virtual returns (bool) {
        return
            interfaceId == type(ContractOffererInterface).interfaceId ||
            interfaceId == type(IERC721Receiver).interfaceId ||
            interfaceId == type(IERC1155Receiver).interfaceId;
    }

    function _createOrder(
        address fulfiller,
        SpentItem[] memory minimumReceived,
        SpentItem[] memory maximumSpent,
        bytes calldata context,
        bool withEffects
    )
        internal
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    {
        // Declare an error buffer; first check is that caller is Seaport.
        uint256 errorBuffer = _cast(msg.sender != _SEAPORT);

        // Next, check the maximum spent is not empty.
        errorBuffer |= _cast(maximumSpent.length != 0) << 1;

        // Get the redemption params hash and load the params from storage.
        bytes32 paramsHash = bytes32(context[0:32]);
        RedeemableRegistryParamsV0 storage params = _redeemableParams[
            paramsHash
        ];

        // Check the redemption is active.
        errorBuffer |=
            _cast(_checkActive(params.startTime, params.endTime)) <<
            2;

        // Check max total redemptions would not be exceeded.
        errorBuffer |=
            _cast(
                _totalRedemptions[paramsHash] + maximumSpent.length >
                    params.maxTotalRedemptions
            ) <<
            3;

        // Check the contract addressses are allowable.
        address unsupportedTokenAddress;
        for (uint256 i = 0; i < maximumSpent.length; ) {
            if (!_isValidTokenAddress(params, maximumSpent[i].token)) {
                unsupportedTokenAddress = maximumSpent[i].token;
                errorBuffer |= 1 << 4;
                break;
            }
            unchecked {
                ++i;
            }
        }

        if (errorBuffer > 0) {
            if (errorBuffer << 255 != 0) {
                revert InvalidCaller(msg.sender);
            } else if (errorBuffer << 254 != 0) {
                revert NotActive(
                    block.timestamp,
                    params.startTime,
                    params.endTime
                );
            } else if (errorBuffer << 253 != 0) {
                revert MaxTotalRedemptionsReached(
                    _totalRedemptions[paramsHash] + maximumSpent.length,
                    params.maxTotalRedemptions
                );
            } else if (errorBuffer << 252 != 0) {
                revert UnsupportedTokenAddress(unsupportedTokenAddress);
            } else {
                // todo more errors
            }
        }

        // If withEffects is true then make state changes.
        if (withEffects) {
            // Increment total redemptions.
            _totalRedemptions[paramsHash] += maximumSpent.length;

            // Emit Redeemed event.
            uint256[] memory tokenIds = new uint256[](maximumSpent.length);
            for (uint256 i = 0; i < maximumSpent.length; ) {
                tokenIds[i] = maximumSpent[i].identifier;
                unchecked {
                    ++i;
                }
            }
            emit Redeemed(maximumSpent[0].token, tokenIds, fulfiller);
        }

        // Off chain redeemables have no offer items.
        offer = new SpentItem[](0);

        // Set the consideration recipients to params.sendTo
        consideration = new ReceivedItem[](maximumSpent.length);
        for (uint256 i = 0; i < maximumSpent.length; ) {
            consideration[i] = ReceivedItem({
                itemType: maximumSpent[i].itemType,
                token: maximumSpent[i].token,
                identifier: maximumSpent[i].identifier,
                amount: maximumSpent[i].amount,
                recipient: payable(params.sendTo)
            });
            unchecked {
                ++i;
            }
        }
    }

    function onERC721Received(
        address /* operator */,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        SpentItem[] memory minimumReceived;

        SpentItem[] memory maximumSpent = new SpentItem[](1);
        maximumSpent[0] = SpentItem({
            itemType: ItemType.ERC721,
            token: msg.sender,
            identifier: tokenId,
            amount: 1
        });

        // _createOrder will revert if any validations fail.
        _createOrder(from, minimumReceived, maximumSpent, data, true);

        // Get the params.
        bytes32 paramsHash = bytes32(data[0:32]);
        RedeemableRegistryParamsV0 storage params = _redeemableParams[
            paramsHash
        ];

        // Transfer the token to params.sendTo
        IERC721(msg.sender).transferFrom(
            address(this),
            payable(params.sendTo),
            tokenId
        );

        return IERC721Receiver.onERC721Received.selector;
    }

    function onERC1155Received(
        address /* operator */,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4) {
        SpentItem[] memory minimumReceived;

        SpentItem[] memory maximumSpent = new SpentItem[](1);
        maximumSpent[0] = SpentItem({
            itemType: ItemType.ERC1155,
            token: msg.sender,
            identifier: id,
            amount: value
        });

        // _createOrder will revert if any validations fail.
        _createOrder(from, minimumReceived, maximumSpent, data, true);

        // Get the params.
        bytes32 paramsHash = bytes32(data[0:32]);
        RedeemableRegistryParamsV0 storage params = _redeemableParams[
            paramsHash
        ];

        // Transfer the token to params.sendTo
        IERC1155(msg.sender).safeTransferFrom(
            address(this),
            payable(params.sendTo),
            id,
            value,
            ""
        );

        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address /* operator */,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4) {
        if (ids.length != values.length) revert RedeemMismatchedLengths();

        SpentItem[] memory minimumReceived;

        SpentItem[] memory maximumSpent = new SpentItem[](ids.length);
        for (uint256 i = 0; i < ids.length; ) {
            maximumSpent[i] = SpentItem({
                itemType: ItemType.ERC1155,
                token: msg.sender,
                identifier: ids[i],
                amount: values[i]
            });
            unchecked {
                ++i;
            }
        }

        // _createOrder will revert if any validations fail.
        _createOrder(from, minimumReceived, maximumSpent, data, true);

        // Get the params.
        bytes32 paramsHash = bytes32(data[0:32]);
        RedeemableRegistryParamsV0 storage params = _redeemableParams[
            paramsHash
        ];

        // Transfer the tokens to params.sendTo
        IERC1155(msg.sender).safeBatchTransferFrom(
            address(this),
            payable(params.sendTo),
            ids,
            values,
            ""
        );

        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    function getRedeemableParams(
        bytes32 redeemableParamsHash
    ) external view returns (RedeemableRegistryParamsV0 memory) {
        return _redeemableParams[redeemableParamsHash];
    }

    function redeemableURI(
        bytes32 redeemableParamsHash
    ) external view returns (string memory) {
        return _redeemableURIs[redeemableParamsHash];
    }

    function _getRedeemableParamsHash(
        RedeemableRegistryParamsV0 memory params
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(params));
    }

    function _checkActive(
        uint256 startTime,
        uint256 endTime
    ) internal view returns (bool inactive) {
        // Using the same check for time boundary from Seaport.
        // startTime <= block.timestamp < endTime
        assembly {
            inactive := or(
                iszero(gt(endTime, timestamp())),
                gt(startTime, timestamp())
            )
        }
    }

    function _isValidTokenAddress(
        RedeemableRegistryParamsV0 memory params,
        address token
    ) internal pure returns (bool valid) {
        for (uint256 i = 0; i < params.consideration.length; ) {
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
    function _removeFromEnumeration(
        uint256 toRemove,
        uint256[] storage enumeration
    ) internal {
        // Cache the length.
        uint256 enumerationLength = enumeration.length;
        for (uint256 i = 0; i < enumerationLength; ) {
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
    function _asAddressArray(
        function(uint256, uint256[] storage) internal fnIn
    )
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

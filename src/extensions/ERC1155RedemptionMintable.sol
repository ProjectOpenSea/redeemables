// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ConsiderationItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {ERC1155ShipyardContractMetadata} from "../lib/ERC1155ShipyardContractMetadata.sol";
import {IRedemptionMintable} from "../interfaces/IRedemptionMintable.sol";
import {TraitRedemption} from "../lib/RedeemablesStructs.sol";

contract ERC1155RedemptionMintable is ERC1155ShipyardContractMetadata, IRedemptionMintable {
    /// @dev The ERC-7498 redeemables contract.
    address internal immutable _ERC7498_REDEEMABLES_CONTRACT;

    /// @dev Revert if the sender of mintRedemption is not the redeemable contract offerer.
    error InvalidSender();

    constructor(string memory name_, string memory symbol_, address redeemableContractOfferer)
        ERC1155ShipyardContractMetadata(name_, symbol_)
    {
        // Set the redeemables contract address.
        _ERC7498_REDEEMABLES_CONTRACT = redeemableContractOfferer;
    }

    function mintRedemption(
        uint256, /* campaignId */
        address recipient,
        ConsiderationItem[] calldata consideration,
        TraitRedemption[] calldata /* traitRedemptions */
    ) external {
        if (msg.sender != _ERC7498_REDEEMABLES_CONTRACT) {
            revert InvalidSender();
        }

        // Mint the same token IDs and amounts redeemed.
        for (uint256 i = 0; i < consideration.length;) {
            ConsiderationItem memory considerationItem = consideration[i];
            _mint(recipient, considerationItem.identifierOrCriteria, considerationItem.startAmount, "");
            unchecked {
                ++i;
            }
        }
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155ShipyardContractMetadata)
        returns (bool)
    {
        return ERC1155ShipyardContractMetadata.supportsInterface(interfaceId)
            || interfaceId == type(IRedemptionMintable).interfaceId;
    }
}

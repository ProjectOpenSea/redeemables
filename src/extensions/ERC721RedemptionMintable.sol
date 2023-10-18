// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ConsiderationItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {ERC721ShipyardContractMetadata} from "../lib/ERC721ShipyardContractMetadata.sol";
import {IRedemptionMintable} from "../interfaces/IRedemptionMintable.sol";
import {TraitRedemption} from "../lib/RedeemablesStructs.sol";

contract ERC721RedemptionMintable is ERC721ShipyardContractMetadata, IRedemptionMintable {
    /// @dev The ERC-7498 redeemables contract.
    address internal immutable _ERC7498_REDEEMABLES_CONTRACT;

    /// @dev The next token id to mint.
    uint256 internal _nextTokenId = 1;

    /// @dev Revert if the sender of mintRedemption is not the redeemable contract offerer.
    error InvalidSender();

    constructor(string memory name_, string memory symbol_, address redeemablesContractAddress)
        ERC721ShipyardContractMetadata(name_, symbol_)
    {
        // Set the redeemables contract address.
        _ERC7498_REDEEMABLES_CONTRACT = redeemablesContractAddress;
    }

    function mintRedemption(
        uint256, /* campaignId */
        address recipient,
        ConsiderationItem[] calldata, /* consideration */
        TraitRedemption[] calldata /* traitRedemptions */
    ) external {
        if (msg.sender != _ERC7498_REDEEMABLES_CONTRACT) {
            revert InvalidSender();
        }

        // Increment nextTokenId first so more of the same token id cannot be minted through reentrancy.
        ++_nextTokenId;

        _mint(recipient, _nextTokenId - 1);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721ShipyardContractMetadata)
        returns (bool)
    {
        return ERC721ShipyardContractMetadata.supportsInterface(interfaceId)
            || interfaceId == type(IRedemptionMintable).interfaceId;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC721ConduitPreapproved_Solady} from "shipyard-core/src/tokens/erc721/ERC721ConduitPreapproved_Solady.sol";
import {ConsiderationItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";
import {ERC7498NFTRedeemables} from "../lib/ERC7498NFTRedeemables.sol";
import {CampaignParams} from "../lib/RedeemablesStructs.sol";
import {IRedemptionMintable} from "../interfaces/IRedemptionMintable.sol";
import {ERC721ShipyardRedeemable} from "../ERC721ShipyardRedeemable.sol";
import {IRedemptionMintable} from "../interfaces/IRedemptionMintable.sol";
import {TraitRedemption} from "../lib/RedeemablesStructs.sol";

contract ERC721ShipyardRedeemableMintable is ERC721ShipyardRedeemable, IRedemptionMintable {
    /// @dev Revert if the sender of mintRedemption is not this contract.
    error InvalidSender();

    function mintRedemption(
        uint256, /* campaignId */
        address recipient,
        ConsiderationItem[] calldata, /* consideration */
        TraitRedemption[] calldata /* traitRedemptions */
    ) external {
        if (msg.sender != address(this)) {
            revert InvalidSender();
        }
        _mint(recipient, 1);
    }

    constructor() ERC721ShipyardRedeemable() {}

    function _useInternalBurn() internal pure override returns (bool) {
        return false;
    }
}

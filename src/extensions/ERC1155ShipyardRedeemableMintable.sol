// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC165} from "openzeppelin-contracts/contracts/interfaces/IERC165.sol";
import {ERC721ConduitPreapproved_Solady} from "shipyard-core/src/tokens/erc721/ERC721ConduitPreapproved_Solady.sol";
import {ConsiderationItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";
import {ERC7498NFTRedeemables} from "../lib/ERC7498NFTRedeemables.sol";
import {CampaignParams} from "../lib/RedeemablesStructs.sol";
import {IRedemptionMintable} from "../interfaces/IRedemptionMintable.sol";
import {ERC1155ShipyardRedeemable} from "../ERC1155ShipyardRedeemable.sol";
import {IRedemptionMintable} from "../interfaces/IRedemptionMintable.sol";
import {TraitRedemption} from "../lib/RedeemablesStructs.sol";

contract ERC1155ShipyardRedeemableMintable is ERC1155ShipyardRedeemable, IRedemptionMintable {
    /// @dev Revert if the sender of mintRedemption is not this contract.
    error InvalidSender();

    /// @dev The next token id to mint. Each token will have a supply of 1.
    uint256 _nextTokenId = 1;

    constructor(string memory name_, string memory symbol_) ERC1155ShipyardRedeemable(name_, symbol_) {}

    function mintRedemption(
        uint256, /* campaignId */
        address recipient,
        ConsiderationItem[] calldata, /* consideration */
        TraitRedemption[] calldata /* traitRedemptions */
    ) external {
        if (msg.sender != address(this)) {
            revert InvalidSender();
        }

        // Increment nextTokenId first so more of the same token id cannot be minted through reentrancy.
        ++_nextTokenId;

        _mint(recipient, _nextTokenId - 1, 1, "");
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155ShipyardRedeemable)
        returns (bool)
    {
        return interfaceId == type(IRedemptionMintable).interfaceId
            || ERC1155ShipyardRedeemable.supportsInterface(interfaceId);
    }
}

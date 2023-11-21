// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC165} from "openzeppelin-contracts/contracts/interfaces/IERC165.sol";
import {ERC721ConduitPreapproved_Solady} from "shipyard-core/src/tokens/erc721/ERC721ConduitPreapproved_Solady.sol";
import {ConsiderationItem, OfferItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";
import {ERC7498NFTRedeemables} from "../lib/ERC7498NFTRedeemables.sol";
import {CampaignParams} from "../lib/RedeemablesStructs.sol";
import {IRedemptionMintable} from "../interfaces/IRedemptionMintable.sol";
import {ERC721ShipyardRedeemable} from "../ERC721ShipyardRedeemable.sol";
import {IRedemptionMintable} from "../interfaces/IRedemptionMintable.sol";
import {TraitRedemption} from "../lib/RedeemablesStructs.sol";

contract ERC721ShipyardRedeemableMintable is ERC721ShipyardRedeemable, IRedemptionMintable {
    /// @dev The ERC-7498 redeemables contracts.
    address[] internal _erc7498RedeemablesContracts;

    /// @dev The next token id to mint.
    uint256 _nextTokenId = 1;

    constructor(string memory name_, string memory symbol_) ERC721ShipyardRedeemable(name_, symbol_) {}

    function mintRedemption(
        uint256, /* campaignId */
        address recipient,
        OfferItem calldata, /* offer */
        ConsiderationItem[] calldata, /* consideration */
        TraitRedemption[] calldata /* traitRedemptions */
    ) external virtual {
        // Require that msg.sender is valid.
        _requireValidRedeemablesCaller();

        // Increment nextTokenId first so more of the same token id cannot be minted through reentrancy.
        ++_nextTokenId;

        _mint(recipient, _nextTokenId - 1);
    }

    function getRedeemablesContracts() external view returns (address[] memory) {
        return _erc7498RedeemablesContracts;
    }

    function setRedeemablesContracts(address[] calldata redeemablesContracts) external onlyOwner {
        _erc7498RedeemablesContracts = redeemablesContracts;
    }

    function _requireValidRedeemablesCaller() internal view {
        // Allow the contract to call itself.
        if (msg.sender == address(this)) return;

        bool validCaller;
        for (uint256 i; i < _erc7498RedeemablesContracts.length; i++) {
            if (msg.sender == _erc7498RedeemablesContracts[i]) {
                validCaller = true;
            }
        }
        if (!validCaller) revert InvalidCaller(msg.sender);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721ShipyardRedeemable)
        returns (bool)
    {
        return interfaceId == type(IRedemptionMintable).interfaceId
            || ERC721ShipyardRedeemable.supportsInterface(interfaceId);
    }
}

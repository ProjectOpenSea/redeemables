// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC165} from "openzeppelin-contracts/contracts/interfaces/IERC165.sol";
import {ConsiderationItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {ERC1155ShipyardContractMetadata} from "../lib/ERC1155ShipyardContractMetadata.sol";
import {IRedemptionMintable} from "../interfaces/IRedemptionMintable.sol";
import {TraitRedemption} from "../lib/RedeemablesStructs.sol";

contract ERC1155RedemptionMintable is ERC1155ShipyardContractMetadata, IRedemptionMintable {
    /// @dev The ERC-7498 redeemables contract.
    address[] internal _ERC7498_REDEEMABLES_CONTRACTS;

    /// @dev The next token id to mint.
    uint256 internal _nextTokenId = 1;

    /// @dev Revert if the sender of mintRedemption is not the redeemable contract offerer.
    error InvalidSender();

    constructor(string memory name_, string memory symbol_, address[] memory redeemableContractAddresses)
        ERC1155ShipyardContractMetadata(name_, symbol_)
    {
        // Set the redeemables contract addresses.
        _ERC7498_REDEEMABLES_CONTRACTS = redeemableContractAddresses;
    }

    function mintRedemption(
        uint256, /* campaignId */
        address recipient,
        ConsiderationItem[] calldata, /* consideration */
        TraitRedemption[] calldata /* traitRedemptions */
    ) external {
        bool validSender;
        for (uint256 i; i < _ERC7498_REDEEMABLES_CONTRACTS.length; i++) {
            if (msg.sender == _ERC7498_REDEEMABLES_CONTRACTS[i]) {
                validSender = true;
            }
        }
        if (!validSender) {
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
        override(ERC1155ShipyardContractMetadata)
        returns (bool)
    {
        return ERC1155ShipyardContractMetadata.supportsInterface(interfaceId)
            || interfaceId == type(IRedemptionMintable).interfaceId;
    }
}

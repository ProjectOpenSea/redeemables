// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC1155} from "solady/src/tokens/ERC1155.sol";
import {IRedemptionMintable} from "../interfaces/IRedemptionMintable.sol";
import {ConsiderationItem} from "seaport-types/src/lib/ConsiderationStructs.sol";

contract ERC1155RedemptionMintable is ERC1155, IRedemptionMintable {
    address internal immutable _ERC7498_REDEEMABLES_CONTRACT;

    /// @dev Revert if the sender of mintRedemption is not the redeemable contract offerer.
    error InvalidSender();

    constructor(address redeemableContractOfferer, address redeemToken) {
        _ERC7498_REDEEMABLES_CONTRACT = redeemableContractOfferer;
    }

    function mintRedemption(uint256, /* campaignId */ address recipient, ConsiderationItem[] calldata consideration)
        external
    {
        if (msg.sender != _ERC7498_REDEEMABLES_CONTRACT) {
            revert InvalidSender();
        }

        // Mint the same token IDs and amounts redeemed.
        for (uint256 i = 0; i < consideration.length; ++i) {
            ConsiderationItem memory considerationItem = consideration[i];
            _mint(recipient, considerationItem.identifierOrCriteria, considerationItem.startAmount, "");
        }
    }

    function uri(uint256 id) public pure override returns (string memory) {
        return string(abi.encodePacked("https://example.com/", id));
    }
}

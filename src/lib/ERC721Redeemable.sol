// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC721} from "solady/src/tokens/ERC721.sol";
import {IERC721Redeemable} from "../interfaces/IERC721Redeemable.sol";
import {RedeemablesErrorsAndEvents} from "./RedeemablesErrorsAndEvents.sol";

contract ERC721Redeemable is ERC721, IERC721Redeemable {
    address internal immutable _REDEEMABLE_CONTRACT_OFFERER;

    /// @dev Revert if the sender of mintRedemption is not the redeemable contract offerer.
    error InvalidSender();

    constructor(address redeemableContractOfferer) {
        _REDEEMABLE_CONTRACT_OFFERER = redeemableContractOfferer;
    }

    function burn(uint256 tokenId) public {
        if (msg.sender != _REDEEMABLE_CONTRACT_OFFERER) revert InvalidSender();

        // Unchecked, does not check if msg.sender is owner or approved operator.
        _burn(tokenId);
    }

    function name() public pure override returns (string memory) {
        return "ERC721RedemptionMintable";
    }

    function symbol() public pure override returns (string memory) {
        return "721RM";
    }

    function tokenURI(uint256 tokenId) public pure override returns (string memory) {
        return string(abi.encodePacked("https://example.com/", tokenId));
    }
}

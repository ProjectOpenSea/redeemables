// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC721} from "solady/src/tokens/ERC721.sol";
import {IERC721RedemptionMintable} from "../interfaces/IERC721RedemptionMintable.sol";
import {RedemptionContextV0} from "../lib/RedeemableStructs.sol";

contract ERC721RedemptionMintable is ERC721, IERC721RedemptionMintable {
    address private _redeemableContractOfferer;

    /// @dev Revert with an error if the redeemable contract offerer is not the sender of mintWithRedemptionContext.
    error InvalidSender();

    constructor(address redeemableContractOfferer) {
        _redeemableContractOfferer = redeemableContractOfferer;
    }

    function mintWithRedemptionContext(address to, RedemptionContextV0 calldata context) external {
        if (msg.sender != _redeemableContractOfferer) revert InvalidSender();

        // Mint the same token IDs redeemed.
        for (uint256 i = 0; i < context.spent.length;) {
            _mint(to, context.spent[i].identifier);

            unchecked {
                ++i;
            }
        }
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

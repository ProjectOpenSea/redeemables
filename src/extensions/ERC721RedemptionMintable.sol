// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC721} from "solady/src/tokens/ERC721.sol";
import {ConsiderationItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {IRedemptionMintable} from "../interfaces/IRedemptionMintable.sol";
import {TraitRedemption} from "../lib/RedeemablesStructs.sol";

contract ERC721RedemptionMintable is ERC721, IRedemptionMintable {
    address internal immutable _ERC7498_REDEEMABLES_CONTRACT;
    uint256 internal _nextTokenId = 1;

    /// @dev Revert if the sender of mintRedemption is not the redeemable contract offerer.
    error InvalidSender();

    constructor(address redeemablesContractAddress) {
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
        _mint(recipient, _nextTokenId);
        ++_nextTokenId;
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

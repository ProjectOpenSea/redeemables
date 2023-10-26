// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC165} from "openzeppelin-contracts/contracts/interfaces/IERC165.sol";
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
    error InvalidTokenURIQuery();

    /// @dev The next token id to mint.
    uint256 _nextTokenId = 1;

    mapping(uint256 => uint256) public tokenURINumbers;

    constructor(string memory name_, string memory symbol_) ERC721ShipyardRedeemable(name_, symbol_) {}

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

        _mint(recipient, _nextTokenId - 1);
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

    /**
     * @notice Hook to set tokenURINumber on mint.
     */
    function _beforeTokenTransfer(address from, address, /* to */ uint256 id) internal virtual override {
        // Set tokenURINumbers on mint.
        if (from == address(0)) {
            // 60% chance of tokenURI 1
            // 30% chance of tokenURI 2
            // 10% chance of tokenURI 3

            // block.difficulty returns PREVRANDAO on Ethereum post-merge
            // NOTE: do not use this on other chains
            uint256 randomness = (uint256(keccak256(abi.encode(block.difficulty))) % 100) + 1;

            uint256 tokenURINumber = 1;
            if (randomness >= 60 && randomness < 90) {
                tokenURINumber = 2;
            } else if (randomness >= 90) {
                tokenURINumber = 3;
            }

            tokenURINumbers[id] = tokenURINumber;
        }
    }

    /*
     * @notice Overrides the `tokenURI()` function to return baseURI + 1, 2, or 3
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) revert InvalidTokenURIQuery();

        uint256 tokenURINumber = tokenURINumbers[tokenId];

        return string(abi.encodePacked(baseURI, _toString(tokenURINumber)));
    }
}

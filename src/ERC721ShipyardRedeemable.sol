// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC721ShipyardContractMetadata} from "./lib/ERC721ShipyardContractMetadata.sol";
import {ERC7498NFTRedeemables} from "./lib/ERC7498NFTRedeemables.sol";
import {CampaignParams} from "./lib/RedeemablesStructs.sol";

contract ERC721ShipyardRedeemable is ERC721ShipyardContractMetadata, ERC7498NFTRedeemables {
    constructor(string memory name_, string memory symbol_) ERC721ShipyardContractMetadata(name_, symbol_) {}

    function createCampaign(CampaignParams calldata params, string calldata uri)
        public
        override
        onlyOwner
        returns (uint256 campaignId)
    {
        campaignId = ERC7498NFTRedeemables.createCampaign(params, uri);
    }

    function _useInternalBurn() internal pure virtual override returns (bool) {
        return true;
    }

    function _internalBurn(address, /* from */ uint256 id, uint256 /* amount */ ) internal virtual override {
        _burn(id);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721ShipyardContractMetadata, ERC7498NFTRedeemables)
        returns (bool)
    {
        return ERC721ShipyardContractMetadata.supportsInterface(interfaceId)
            || ERC7498NFTRedeemables.supportsInterface(interfaceId);
    }
}

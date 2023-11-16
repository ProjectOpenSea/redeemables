// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC1155ShipyardContractMetadata} from "./lib/ERC1155ShipyardContractMetadata.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";
import {ERC7498NFTRedeemables} from "./lib/ERC7498NFTRedeemables.sol";
import {DynamicTraits} from "shipyard-core/src/dynamic-traits/DynamicTraits.sol";
import {Campaign} from "./lib/RedeemablesStructs.sol";

contract ERC1155ShipyardRedeemable is ERC1155ShipyardContractMetadata, ERC7498NFTRedeemables {
    constructor(string memory name_, string memory symbol_) ERC1155ShipyardContractMetadata(name_, symbol_) {}

    function createCampaign(Campaign calldata campaign, string calldata metadataURI)
        public
        override
        onlyOwner
        returns (uint256 campaignId)
    {
        campaignId = ERC7498NFTRedeemables.createCampaign(campaign, metadataURI);
    }

    function setTrait(uint256 tokenId, bytes32 traitKey, bytes32 value) public virtual override onlyOwner {
        DynamicTraits.setTrait(tokenId, traitKey, value);
    }

    function _useInternalBurn() internal pure virtual override returns (bool) {
        return true;
    }

    function _internalBurn(address from, uint256 id, uint256 amount) internal virtual override {
        _burn(from, id, amount);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155ShipyardContractMetadata, ERC7498NFTRedeemables)
        returns (bool)
    {
        return ERC1155ShipyardContractMetadata.supportsInterface(interfaceId)
            || ERC7498NFTRedeemables.supportsInterface(interfaceId);
    }
}

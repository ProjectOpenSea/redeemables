// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC1155ShipyardContractMetadata} from "./lib/ERC1155ShipyardContractMetadata.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";
import {ERC7498NFTRedeemables} from "./lib/ERC7498NFTRedeemables.sol";
import {CampaignParams} from "./lib/RedeemablesStructs.sol";

contract ERC1155ShipyardRedeemable is ERC1155ShipyardContractMetadata, ERC7498NFTRedeemables {
    constructor(string memory name_, string memory symbol_) ERC1155ShipyardContractMetadata(name_, symbol_) {}

    function createCampaign(CampaignParams calldata params, string calldata uri_)
        public
        override
        onlyOwner
        returns (uint256 campaignId)
    {
        campaignId = ERC7498NFTRedeemables.createCampaign(params, uri_);
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

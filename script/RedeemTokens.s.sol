// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {ItemType} from "seaport-types/src/lib/ConsiderationEnums.sol";
import {OfferItem, ConsiderationItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {CampaignParams, CampaignRequirements} from "../src/lib/RedeemablesStructs.sol";
import {ERC721ShipyardRedeemableMintable} from "../src/extensions/ERC721ShipyardRedeemableMintable.sol";
import {ERC721ShipyardRedeemableOwnerMintable} from "../src/test/ERC721ShipyardRedeemableOwnerMintable.sol";
import {ERC1155ShipyardRedeemableMintable} from "../src/extensions/ERC1155ShipyardRedeemableMintable.sol";

contract RedeemTokens is Script, Test {
    function run() external {
        vm.startBroadcast();

        // address redeemToken = 0x1eCC76De3f9E4e9f8378f6ade61A02A10f976c45;
        ERC1155ShipyardRedeemableMintable receiveToken =
            ERC1155ShipyardRedeemableMintable(0x3D0fa2a8D07dfe357905a4cB4ed51b0Aea8385B9);

        // Let's redeem them!
        uint256[] memory traitRedemptionTokenIds;
        bytes memory data = abi.encode(
            1, // campaignId
            0, // requirementsIndex
            bytes32(0), // redemptionHash
            traitRedemptionTokenIds,
            uint256(0), // salt
            bytes("") // signature
        );

        uint256[] memory redeemTokenIds = new uint256[](1);
        redeemTokenIds[0] = 1;

        // Individual user approvals not needed if preapproved.
        // redeemToken.setApprovalForAll(address(receiveToken), true);

        receiveToken.redeem(redeemTokenIds, msg.sender, data);
    }
}

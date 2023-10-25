// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {ItemType} from "seaport-types/src/lib/ConsiderationEnums.sol";
import {OfferItem, ConsiderationItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {CampaignParams, CampaignRequirements} from "../src/lib/RedeemablesStructs.sol";
import {ERC721RedemptionMintable} from "../src/extensions/ERC721RedemptionMintable.sol";
import {ERC721OwnerMintable} from "../src/test/ERC721OwnerMintable.sol";
import {ERC1155ShipyardRedeemableMintable} from "../src/extensions/ERC1155ShipyardRedeemableMintable.sol";

contract RedeemTokens is Script, Test {
    function run() external {
        vm.startBroadcast();

        address redeemToken = 0x8fe638b493e1C548456F3E74B80D4Eb4ca4a1825;
        ERC1155ShipyardRedeemableMintable receiveToken =
            ERC1155ShipyardRedeemableMintable(0x9E0B99a4f213439Be7F25f5C1e42087aF65F1b0A);

        // Let's redeem them!
        uint256 campaignId = 1;
        uint256 requirementsIndex = 0;
        bytes32 redemptionHash = bytes32(0);
        bytes memory data = abi.encode(campaignId, requirementsIndex, redemptionHash);

        uint256[] memory redeemTokenIds = new uint256[](1);
        redeemTokenIds[0] = 1;

        // Individual user approvals not needed if preapproved.
        // redeemToken.setApprovalForAll(address(receiveToken), true);

        receiveToken.redeem(redeemTokenIds, msg.sender, data);
    }
}

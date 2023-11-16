// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {ItemType} from "seaport-types/src/lib/ConsiderationEnums.sol";
import {OfferItem, ConsiderationItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {Campaign, CampaignParams, CampaignRequirements} from "../src/lib/RedeemablesStructs.sol";
import {BURN_ADDRESS} from "../src/lib/RedeemablesConstants.sol";
import {ERC721ShipyardRedeemableMintable} from "../src/extensions/ERC721ShipyardRedeemableMintable.sol";
import {ERC721ShipyardRedeemableOwnerMintable} from "../src/test/ERC721ShipyardRedeemableOwnerMintable.sol";

contract DeployAndRedeemTokens_CampaignOnReceiveToken is Script, Test {
    function run() external {
        vm.startBroadcast();

        ERC721ShipyardRedeemableOwnerMintable redeemToken =
            new ERC721ShipyardRedeemableOwnerMintable("TestRedeemablesRedeemToken", "TEST-RDM");
        ERC721ShipyardRedeemableMintable receiveToken =
            new ERC721ShipyardRedeemableMintable("TestRedeemablesReceiveToken", "TEST-RCV");

        // Configure the campaign.
        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItem({
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: address(receiveToken),
            identifierOrCriteria: 0,
            startAmount: 1,
            endAmount: 1
        });

        ConsiderationItem[] memory consideration = new ConsiderationItem[](1);
        consideration[0] = ConsiderationItem({
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: address(redeemToken),
            identifierOrCriteria: 0,
            startAmount: 1,
            endAmount: 1,
            recipient: payable(BURN_ADDRESS)
        });

        CampaignRequirements[] memory requirements = new CampaignRequirements[](
            1
        );
        requirements[0].offer = offer;
        requirements[0].consideration = consideration;

        CampaignParams memory params = CampaignParams({
            startTime: uint32(block.timestamp),
            endTime: uint32(block.timestamp + 1_000_000),
            maxCampaignRedemptions: 1_000,
            manager: msg.sender,
            signer: address(0)
        });
        Campaign memory campaign = Campaign({params: params, requirements: requirements});
        uint256 campaignId =
            receiveToken.createCampaign(campaign, "ipfs://QmbFxYgQMoBSUNFyW7WRWGaAWwJiRPM6HbK86aFkSJSq5N");

        // Mint token 1 to redeem for token 1.
        redeemToken.mint(msg.sender, 1);
        redeemToken.mint(msg.sender, 2);
        redeemToken.mint(msg.sender, 3);
        redeemToken.mint(msg.sender, 4);

        // Let's redeem them!
        uint256[] memory traitRedemptionTokenIds;
        bytes memory data = abi.encode(
            campaignId,
            0, // requirementsIndex
            bytes32(0), // redemptionHash
            traitRedemptionTokenIds,
            uint256(0), // salt
            bytes("") // signature
        );

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        // Individual user approvals not needed when setting the burn address.
        redeemToken.setApprovalForAll(address(receiveToken), true);
        // redeemToken.setBurnAddress(address(receiveToken));

        receiveToken.redeem(tokenIds, msg.sender, data);

        // Assert redeemable token is burned and redemption token is minted.
        assertEq(redeemToken.balanceOf(msg.sender), 0);
        assertEq(receiveToken.ownerOf(1), msg.sender);
    }
}

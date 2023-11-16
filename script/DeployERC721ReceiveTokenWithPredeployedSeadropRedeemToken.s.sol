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

contract DeployERC721ReceiveTokenWithPredeployedSeaDropRedeemToken is Script, Test {
    function run() external {
        vm.startBroadcast();

        ERC721ShipyardRedeemableMintable redeemToken =
            ERC721ShipyardRedeemableMintable(0xa1783E74857736b2AEE610A36b537B31CC333048);
        ERC721ShipyardRedeemableMintable receiveToken =
            ERC721ShipyardRedeemableMintable(0x343B9aEC7fAB02d07c6747Bace112920822334B4);

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
            receiveToken.createCampaign(campaign, "ipfs://QmQKc93y2Ev5k9Kz54mCw48ZM487bwGDktZYPLtrjJ3r1d");

        // redeemToken.setBaseURI(
        //     "ipfs://QmYTSupCtriDLBHgPBBhZ98wYdp6N9S8jTL5sKSZwbASeT"
        // );

        // receiveToken.setBaseURI(
        //     "ipfs://QmWxgnz8T9wsMBmpCY4Cvanj3RR1obFD2hqDKPZhKN5Tsq/"
        // );

        // Let's redeem them!
        uint256 requirementsIndex = 0;
        bytes32 redemptionHash;
        uint256 salt;
        bytes memory signature;
        bytes memory data = abi.encode(campaignId, requirementsIndex, redemptionHash, salt, signature);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        redeemToken.setApprovalForAll(address(receiveToken), true);

        receiveToken.redeem(tokenIds, msg.sender, data);

        // Assert redeemable token is burned and redemption token is minted.
        assertEq(redeemToken.balanceOf(msg.sender), 2);
        assertEq(receiveToken.ownerOf(1), msg.sender);
    }
}

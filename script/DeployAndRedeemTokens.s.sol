// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {ItemType} from "seaport-types/src/lib/ConsiderationEnums.sol";
import {OfferItem, ConsiderationItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {CampaignParams, CampaignRequirements} from "../src/lib/RedeemablesStructs.sol";
import {ERC721RedemptionMintable} from "../src/lib/ERC721RedemptionMintable.sol";
import {ERC721ShipyardRedeemableMintable} from "../src/lib/ERC721ShipyardRedeemableMintable.sol";
import {TestERC721} from "../test/utils/mocks/TestERC721.sol";

contract DeployAndRedeemTokens is Script, Test {
    address constant _BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    function run() external {
        vm.startBroadcast();

        ERC721ShipyardRedeemableMintable redeemToken = new ERC721ShipyardRedeemableMintable();
        ERC721RedemptionMintable receiveToken = new ERC721RedemptionMintable(
            address(redeemToken)
        );

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
            recipient: payable(_BURN_ADDRESS)
        });

        CampaignRequirements[] memory requirements = new CampaignRequirements[](1);
        requirements[0].offer = offer;
        requirements[0].consideration = consideration;

        CampaignParams memory params = CampaignParams({
            requirements: requirements,
            signer: address(0),
            startTime: uint32(block.timestamp),
            endTime: uint32(block.timestamp + 1_000_000),
            maxCampaignRedemptions: 1_000,
            manager: msg.sender
        });
        redeemToken.createCampaign(params, "");

        // Mint token 1 to redeem for token 1.
        redeemToken.mint(msg.sender, 1);

        // Let's redeem them!
        uint256 campaignId = 1;
        uint256 requirementsIndex = 0;
        bytes32 redemptionHash = bytes32(0);
        bytes memory data = abi.encode(campaignId, requirementsIndex, redemptionHash);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;
        uint256[][] memory redemptions = new uint256[][](1);
        redemptions[0] = tokenIds;

        redeemToken.redeem(redemptions, msg.sender, data);

        // Assert redeemable token is burned and redemption token is minted.
        assertEq(redeemToken.balanceOf(msg.sender), 0);
        assertEq(receiveToken.ownerOf(1), msg.sender);
    }
}

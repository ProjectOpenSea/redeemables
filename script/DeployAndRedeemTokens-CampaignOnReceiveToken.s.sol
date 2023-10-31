// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {ItemType} from "seaport-types/src/lib/ConsiderationEnums.sol";
import {OfferItem, ConsiderationItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {CampaignParams, CampaignRequirements} from "../src/lib/RedeemablesStructs.sol";
import {ERC721RedemptionMintable} from "../src/extensions/ERC721RedemptionMintable.sol";
import {ERC721OwnerMintable} from "../src/test/ERC721OwnerMintable.sol";
import {ERC721ShipyardRedeemableMintable} from "../src/extensions/ERC721ShipyardRedeemableMintable.sol";

contract DeployAndRedeemTokens_CampaignOnReceiveToken is Script, Test {
    address constant _BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    function run() external {
        vm.startBroadcast();

        ERC721ShipyardRedeemableMintable redeemToken =
            ERC721ShipyardRedeemableMintable(0xe0535403Af71813B59bcEae5F8F6685B7daF6d07);
        ERC721ShipyardRedeemableMintable receiveToken = new ERC721ShipyardRedeemableMintable(
                "Demo 721 Receive Token",
                "DemoReceive721"
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

        CampaignRequirements[] memory requirements = new CampaignRequirements[](
            1
        );
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
        uint256 campaignId =
            receiveToken.createCampaign(params, "ipfs://QmQKc93y2Ev5k9Kz54mCw48ZM487bwGDktZYPLtrjJ3r1d");

        assertEq(campaignId, 1);
        // // redeemToken.setBaseURI(
        // //     "ipfs://QmYTSupCtriDLBHgPBBhZ98wYdp6N9S8jTL5sKSZwbASeT"
        // // );
        receiveToken.setBaseURI("ipfs://QmWxgnz8T9wsMBmpCY4Cvanj3RR1obFD2hqDKPZhKN5Tsq/");

        // // Mint token 1 to redeem for token 1.
        // redeemToken.mint(msg.sender, 1);

        // Let's redeem them!
        // uint256 requirementsIndex = 0;
        // bytes32 redemptionHash = bytes32(0);
        // bytes memory data = abi.encode(1, requirementsIndex, redemptionHash);

        // uint256[] memory tokenIds = new uint256[](1);
        // tokenIds[0] = 2;

        // // Individual user approvals not needed when setting the burn address.
        // // redeemToken.setApprovalForAll(address(receiveToken), true);
        // // redeemToken.setBurnAddress(address(receiveToken));

        // receiveToken.redeem(tokenIds, msg.sender, data);

        // Assert redeemable token is burned and redemption token is minted.
        // assertEq(redeemToken.balanceOf(msg.sender), 0);
        // assertEq(receiveToken.ownerOf(1), msg.sender);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/Test.sol";
import {ItemType} from "seaport-types/src/lib/ConsiderationEnums.sol";
import {OfferItem, ConsiderationItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {RedeemableContractOfferer} from "../src/RedeemableContractOfferer.sol";
import {CampaignParams} from "../src/lib/RedeemablesStructs.sol";
import {ERC721RedemptionMintable} from "../src/lib/ERC721RedemptionMintable.sol";
import {ERC7498NFTRedeemables} from "../src/lib/ERC7498NFTRedeemables.sol";
import {TestERC721} from "../test/utils/mocks/TestERC721.sol";

contract DeployAndRedeemGreenfieldToken is Script, Test {
    address constant _BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    function run() external {
        vm.startBroadcast();

        ERC7498NFTRedeemables redeemableToken = new ERC7498NFTRedeemables();
        ERC721RedemptionMintable redemptionToken = new ERC721RedemptionMintable(
            address(redeemableToken),
            address(redeemableToken)
        );

        // Configure the campaign.
        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItem({
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: address(redemptionToken),
            identifierOrCriteria: 0,
            startAmount: 1,
            endAmount: 1
        });

        ConsiderationItem[] memory consideration = new ConsiderationItem[](1);
        consideration[0] = ConsiderationItem({
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: address(redeemableToken),
            identifierOrCriteria: 0,
            startAmount: 1,
            endAmount: 1,
            recipient: payable(address(0))
        });

        CampaignParams memory params = CampaignParams({
            offer: offer,
            consideration: consideration,
            signer: address(0),
            startTime: uint32(block.timestamp),
            endTime: uint32(block.timestamp + 1_000_000),
            maxCampaignRedemptions: 1_000,
            manager: msg.sender
        });
        redeemableToken.createCampaign(params, "");

        // Mint token 1 to redeem for token 1.
        redeemableToken.mint(msg.sender, 1);

        // Set approvals for the token.
        redeemableToken.setApprovalForAll(address(redeemableToken), true);

        // Let's redeem them!
        uint256 campaignId = 1;
        bytes32 redemptionHash = bytes32(0);
        bytes memory data = abi.encode(campaignId, redemptionHash);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        redeemableToken.redeem(tokenIds, msg.sender, data);

        // Assert redeemable token is burned and redemption token is minted.
        assertEq(redeemableToken.balanceOf(msg.sender), 0);
        assertEq(redemptionToken.ownerOf(1), msg.sender);
    }
}

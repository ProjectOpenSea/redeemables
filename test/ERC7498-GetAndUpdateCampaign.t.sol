// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {BaseRedeemablesTest} from "./utils/BaseRedeemablesTest.sol";
import {Solarray} from "solarray/Solarray.sol";
import {OfferItem, ConsiderationItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {OfferItemLib} from "seaport-sol/src/lib/OfferItemLib.sol";
import {ConsiderationItemLib} from "seaport-sol/src/lib/ConsiderationItemLib.sol";
import {IERC7498} from "../src/interfaces/IERC7498.sol";
import {BURN_ADDRESS} from "../src/lib/RedeemablesConstants.sol";
import {Campaign, CampaignParams, CampaignRequirements} from "../src/lib/RedeemablesStructs.sol";
import {RedeemablesErrors} from "../src/lib/RedeemablesErrors.sol";

contract ERC7498_GetAndUpdateCampaign is BaseRedeemablesTest {
    using OfferItemLib for OfferItem;
    using OfferItemLib for OfferItem[];
    using ConsiderationItemLib for ConsiderationItem;
    using ConsiderationItemLib for ConsiderationItem[];

    function testGetAndUpdateCampaign() public {
        for (uint256 i; i < erc7498Tokens.length; i++) {
            testRedeemable(this.getAndUpdateCampaign, RedeemablesContext({erc7498Token: IERC7498(erc7498Tokens[i])}));
        }
    }

    function getAndUpdateCampaign(RedeemablesContext memory context) external {
        // Should revert if the campaign does not exist.
        for (uint256 i = 0; i < 3; i++) {
            vm.expectRevert(InvalidCampaignId.selector);
            context.erc7498Token.getCampaign(i);
        }

        ConsiderationItem[] memory consideration = new ConsiderationItem[](1);
        consideration[0] = _getCampaignConsiderationItem(address(context.erc7498Token));
        CampaignRequirements[] memory requirements = new CampaignRequirements[](1);
        requirements[0] = CampaignRequirements({
            offer: defaultCampaignOffer,
            consideration: consideration,
            traitRedemptions: defaultTraitRedemptions
        });
        CampaignParams memory params = CampaignParams({
            startTime: uint32(block.timestamp),
            endTime: uint32(block.timestamp + 1000),
            maxCampaignRedemptions: 5,
            manager: address(this),
            signer: address(0)
        });
        Campaign memory campaign = Campaign({params: params, requirements: requirements});
        uint256 campaignId = context.erc7498Token.createCampaign(campaign, "test123");

        (Campaign memory gotCampaign, string memory metadataURI, uint256 totalRedemptions) =
            IERC7498(context.erc7498Token).getCampaign(campaignId);
        assertEq(keccak256(abi.encode(gotCampaign)), keccak256(abi.encode(campaign)));
        assertEq(metadataURI, "test123");
        assertEq(totalRedemptions, 0);

        // Should revert if the campaign does not exist.
        vm.expectRevert(InvalidCampaignId.selector);
        context.erc7498Token.getCampaign(campaignId + 1);

        // Should revert if trying to get campaign id 0, since it starts at 1.
        vm.expectRevert(InvalidCampaignId.selector);
        context.erc7498Token.getCampaign(0);

        // Should revert if updating an invalid campaign id.
        vm.expectRevert(InvalidCampaignId.selector);
        context.erc7498Token.updateCampaign(0, campaign, "test111");
        vm.expectRevert(InvalidCampaignId.selector);
        context.erc7498Token.updateCampaign(campaignId + 1, campaign, "test111");

        // Update the campaign.
        campaign.params.endTime = 0;
        campaign.params.manager = address(0);
        // Should expect revert with InvalidTime since endTime > startTime.
        vm.expectRevert(InvalidTime.selector);
        context.erc7498Token.updateCampaign(campaignId, campaign, "test456");

        campaign.params.startTime = 0;
        context.erc7498Token.updateCampaign(campaignId, campaign, "test456");

        (gotCampaign, metadataURI, totalRedemptions) = IERC7498(context.erc7498Token).getCampaign(campaignId);
        assertEq(keccak256(abi.encode(gotCampaign)), keccak256(abi.encode(campaign)));
        assertEq(metadataURI, "test456");
        assertEq(totalRedemptions, 0);

        // Updating the campaign again should fail since the manager is now the null address.
        vm.expectRevert(NotManager.selector);
        context.erc7498Token.updateCampaign(campaignId, campaign, "test456");
    }

    function testCampaignReverts() public {
        for (uint256 i; i < erc7498Tokens.length; i++) {
            testRedeemable(this.campaignReverts, RedeemablesContext({erc7498Token: IERC7498(erc7498Tokens[i])}));
        }
    }

    function campaignReverts(RedeemablesContext memory context) external {
        ConsiderationItem[] memory consideration = new ConsiderationItem[](1);
        consideration[0] = _getCampaignConsiderationItem(address(context.erc7498Token));
        CampaignRequirements[] memory requirements = new CampaignRequirements[](1);
        requirements[0] = CampaignRequirements({
            offer: defaultCampaignOffer,
            consideration: consideration,
            traitRedemptions: defaultTraitRedemptions
        });
        CampaignParams memory params = CampaignParams({
            startTime: uint32(block.timestamp),
            endTime: uint32(block.timestamp + 1000),
            maxCampaignRedemptions: 5,
            manager: address(this),
            signer: address(0)
        });
        Campaign memory campaign = Campaign({params: params, requirements: requirements});

        consideration[0].recipient = payable(address(0));
        vm.expectRevert(ConsiderationItemRecipientCannotBeZeroAddress.selector);
        context.erc7498Token.createCampaign(campaign, "test123");
        consideration[0].recipient = payable(BURN_ADDRESS);

        consideration[0].startAmount = 0;
        consideration[0].endAmount = 0;
        vm.expectRevert(ConsiderationItemAmountCannotBeZero.selector);
        context.erc7498Token.createCampaign(campaign, "test123");
        consideration[0].startAmount = 1;
        consideration[0].endAmount = 1;

        consideration[0].endAmount = 2;
        vm.expectRevert(abi.encodeWithSelector(NonMatchingConsiderationItemAmounts.selector, 0, 1, 2));
        context.erc7498Token.createCampaign(campaign, "test123");
    }
}

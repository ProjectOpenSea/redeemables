// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Solarray} from "solarray/Solarray.sol";
import {BaseOrderTest} from "./utils/BaseOrderTest.sol";
import {TestERC721} from "./utils/mocks/TestERC721.sol";
import {OfferItem, ConsiderationItem, SpentItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {ItemType} from "seaport-sol/src/SeaportEnums.sol";
import {ConsiderationItemLib} from "seaport-sol/src/lib/ConsiderationItemLib.sol";
import {OfferItemLib} from "seaport-sol/src/lib/OfferItemLib.sol";
import {RedeemableContractOffererV0} from "../src/RedeemableContractOffererV0.sol";
import {CampaignParamsV0} from "../src/lib/RedeemableStructs.sol";
import {RedeemableErrorsAndEvents} from "../src/lib/RedeemableErrorsAndEvents.sol";

contract TestRedeemableContractOffererV0 is BaseOrderTest, RedeemableErrorsAndEvents {
    RedeemableContractOffererV0 offerer;

    address constant _BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    function setUp() public override {
        offerer = new RedeemableContractOffererV0(address(seaport));
    }

    function testUpdateParamsAndURI() public {
        CampaignParamsV0 memory params = CampaignParamsV0({
            offer: new OfferItem[](0),
            consideration: new ConsiderationItem[](1),
            signer: address(0),
            startTime: uint32(block.timestamp),
            endTime: uint32(block.timestamp + 1000),
            maxTotalRedemptions: 5,
            manager: address(this)
        });
        params.consideration[0].recipient = payable(_BURN_ADDRESS);

        uint256 campaignId = 1;
        vm.expectEmit(true, true, true, true);
        emit CampaignUpdated(campaignId, params, "http://test.com");

        offerer.updateCampaign(0, params, "http://test.com");

        (CampaignParamsV0 memory storedParams, string memory storedURI, uint256 totalRedemptions) =
            offerer.getCampaign(campaignId);
        assertEq(storedParams.manager, address(this));
        assertEq(storedURI, "http://test.com");
        assertEq(totalRedemptions, 0);

        params.endTime = uint32(block.timestamp + 2000);

        vm.expectEmit(true, true, true, true);
        emit CampaignUpdated(campaignId, params, "http://test.com");

        offerer.updateCampaign(campaignId, params, "");

        (storedParams, storedURI,) = offerer.getCampaign(campaignId);
        assertEq(storedParams.endTime, params.endTime);
        assertEq(storedParams.manager, address(this));
        assertEq(storedURI, "http://test.com");

        vm.expectEmit(true, true, true, true);
        emit CampaignUpdated(campaignId, params, "http://example.com");

        offerer.updateCampaign(campaignId, params, "http://example.com");

        (, storedURI,) = offerer.getCampaign(campaignId);
        assertEq(storedURI, "http://example.com");

        vm.expectEmit(true, true, true, true);
        emit CampaignUpdated(campaignId, params, "http://foobar.com");

        offerer.updateCampaignURI(campaignId, "http://foobar.com");

        (, storedURI,) = offerer.getCampaign(campaignId);
        assertEq(storedURI, "http://foobar.com");
    }

    function testRedeemWith721SafeTransferFrom() public {
        TestERC721 token = new TestERC721();
        uint256 tokenId = 1;
        token.mint(address(this), tokenId);

        OfferItem[] memory offer;
        ConsiderationItem[] memory consideration = new ConsiderationItem[](1);
        consideration[0] = ConsiderationItem({
            itemType: ItemType.ERC721,
            token: address(token),
            identifierOrCriteria: 0,
            startAmount: 1,
            endAmount: 1,
            recipient: payable(_BURN_ADDRESS)
        });

        CampaignParamsV0 memory params = CampaignParamsV0({
            offer: offer,
            consideration: consideration,
            signer: address(0),
            startTime: uint32(block.timestamp),
            endTime: uint32(block.timestamp + 1000),
            maxTotalRedemptions: 5,
            manager: address(this)
        });

        offerer.updateCampaign(0, params, "");

        ConsiderationItem[] memory expectedConsideration = consideration;
        expectedConsideration[0].identifierOrCriteria = tokenId;
        expectedConsideration[0].startAmount = 1;
        expectedConsideration[0].endAmount = 1;
        uint256 campaignId = 1;
        bytes32 redemptionHash = bytes32(0);
        vm.expectEmit(true, true, true, true);
        emit Redemption(
            address(this),
            campaignId,
            ConsiderationItemLib.toSpentItemArray(consideration),
            OfferItemLib.toSpentItemArray(offer),
            redemptionHash
        );

        bytes memory data = abi.encode(campaignId, redemptionHash);
        token.safeTransferFrom(address(this), address(offerer), tokenId, data);

        assertEq(token.ownerOf(1), _BURN_ADDRESS);
    }
}

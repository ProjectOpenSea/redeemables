// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Solarray} from "solarray/Solarray.sol";
import {BaseOrderTest} from "./utils/BaseOrderTest.sol";
import {TestERC721} from "./utils/mocks/TestERC721.sol";
import {
    OfferItem,
    ConsiderationItem,
    SpentItem,
    AdvancedOrder,
    OrderParameters,
    CriteriaResolver
} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {ItemType, OrderType} from "seaport-sol/src/SeaportEnums.sol";
import {OfferItemLib, ConsiderationItemLib, OrderParametersLib} from "seaport-sol/src/SeaportSol.sol";
import {RedeemableContractOffererV0} from "../src/RedeemableContractOffererV0.sol";
import {CampaignParamsV0} from "../src/lib/RedeemableStructs.sol";
import {RedeemableErrorsAndEvents} from "../src/lib/RedeemableErrorsAndEvents.sol";
import {ERC721RedemptionMintable} from "../src/lib/ERC721RedemptionMintable.sol";

contract TestRedeemableContractOffererV0 is BaseOrderTest, RedeemableErrorsAndEvents {
    using OrderParametersLib for OrderParameters;

    RedeemableContractOffererV0 offerer;
    TestERC721 redeemableToken;
    ERC721RedemptionMintable redemptionToken;
    CriteriaResolver[] criteriaResolvers;

    address constant _BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    function setUp() public override {
        super.setUp();
        offerer = new RedeemableContractOffererV0(address(conduit), address(seaport));
        redeemableToken = new TestERC721();
        redemptionToken = new ERC721RedemptionMintable(address(offerer), address(redeemableToken));
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
        uint256 tokenId = 1;
        redeemableToken.mint(address(this), tokenId);

        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItem({
            itemType: ItemType.ERC721,
            token: address(redemptionToken),
            identifierOrCriteria: 0,
            startAmount: 1,
            endAmount: 1
        });

        ConsiderationItem[] memory consideration = new ConsiderationItem[](1);
        consideration[0] = ConsiderationItem({
            itemType: ItemType.ERC721,
            token: address(redeemableToken),
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
        redeemableToken.safeTransferFrom(address(this), address(offerer), tokenId, data);

        assertEq(redeemableToken.ownerOf(tokenId), _BURN_ADDRESS);
        assertEq(redemptionToken.ownerOf(tokenId), address(this));
    }

    function testRedeemWithSeaport() public {
        uint256 tokenId = 2;
        redeemableToken.mint(address(this), tokenId);
        redeemableToken.setApprovalForAll(address(seaport), true);

        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItem({
            itemType: ItemType.ERC721,
            token: address(redemptionToken),
            identifierOrCriteria: tokenId,
            startAmount: 1,
            endAmount: 1
        });

        ConsiderationItem[] memory consideration = new ConsiderationItem[](1);
        consideration[0] = ConsiderationItem({
            itemType: ItemType.ERC721,
            token: address(redeemableToken),
            identifierOrCriteria: tokenId,
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

        bytes memory extraData = abi.encode(campaignId, redemptionHash);
        OrderParameters memory parameters = OrderParametersLib.empty().withOfferer(address(offerer)).withOrderType(
            OrderType.CONTRACT
        ).withConsideration(consideration).withOffer(offer).withStartTime(block.timestamp).withEndTime(
            block.timestamp + 1
        ).withTotalOriginalConsiderationItems(consideration.length);
        AdvancedOrder memory order =
            AdvancedOrder({parameters: parameters, numerator: 1, denominator: 1, signature: "", extraData: extraData});

        seaport.fulfillAdvancedOrder({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });

        assertEq(redeemableToken.ownerOf(tokenId), _BURN_ADDRESS);
        assertEq(redemptionToken.ownerOf(tokenId), address(this));
    }
}

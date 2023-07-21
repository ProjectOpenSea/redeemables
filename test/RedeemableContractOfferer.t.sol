// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Solarray} from "solarray/Solarray.sol";
import {BaseOrderTest} from "./utils/BaseOrderTest.sol";
import {TestERC721} from "./utils/mocks/TestERC721.sol";
import {OfferItem, ConsiderationItem, SpentItem, AdvancedOrder, OrderParameters, CriteriaResolver, FulfillmentComponent} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {ItemType, OrderType} from "seaport-sol/src/SeaportEnums.sol";
import {OfferItemLib, ConsiderationItemLib, OrderParametersLib} from "seaport-sol/src/SeaportSol.sol";
import {RedeemableContractOfferer} from "../src/RedeemableContractOfferer.sol";
import {CampaignParams} from "../src/lib/RedeemableStructs.sol";
import {RedeemableErrorsAndEvents} from "../src/lib/RedeemableErrorsAndEvents.sol";
import {ERC721RedemptionMintable} from "../src/lib/ERC721RedemptionMintable.sol";

contract TestRedeemableContractOfferer is
    BaseOrderTest,
    RedeemableErrorsAndEvents
{
    using OrderParametersLib for OrderParameters;

    RedeemableContractOfferer offerer;
    TestERC721 redeemableToken;
    ERC721RedemptionMintable redemptionToken;
    CriteriaResolver[] criteriaResolvers;

    address constant _BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    function setUp() public override {
        super.setUp();
        offerer = new RedeemableContractOfferer(
            address(conduit),
            address(seaport)
        );
        redeemableToken = new TestERC721();
        redemptionToken = new ERC721RedemptionMintable(
            address(offerer),
            address(redeemableToken)
        );
    }

    function testUpdateParamsAndURI() public {
        CampaignParams memory params = CampaignParams({
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

        (
            CampaignParams memory storedParams,
            string memory storedURI,
            uint256 totalRedemptions
        ) = offerer.getCampaign(campaignId);
        assertEq(storedParams.manager, address(this));
        assertEq(storedURI, "http://test.com");
        assertEq(totalRedemptions, 0);

        params.endTime = uint32(block.timestamp + 2000);

        vm.expectEmit(true, true, true, true);
        emit CampaignUpdated(campaignId, params, "http://test.com");

        offerer.updateCampaign(campaignId, params, "");

        (storedParams, storedURI, ) = offerer.getCampaign(campaignId);
        assertEq(storedParams.endTime, params.endTime);
        assertEq(storedParams.manager, address(this));
        assertEq(storedURI, "http://test.com");

        vm.expectEmit(true, true, true, true);
        emit CampaignUpdated(campaignId, params, "http://example.com");

        offerer.updateCampaign(campaignId, params, "http://example.com");

        (, storedURI, ) = offerer.getCampaign(campaignId);
        assertEq(storedURI, "http://example.com");

        vm.expectEmit(true, true, true, true);
        emit CampaignUpdated(campaignId, params, "http://foobar.com");

        offerer.updateCampaignURI(campaignId, "http://foobar.com");

        (, storedURI, ) = offerer.getCampaign(campaignId);
        assertEq(storedURI, "http://foobar.com");
    }

    function testRedeemWith721SafeTransferFrom() public {
        uint256 tokenId = 1;
        redeemableToken.mint(address(this), tokenId);

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
            recipient: payable(_BURN_ADDRESS)
        });

        CampaignParams memory params = CampaignParams({
            offer: offer,
            consideration: consideration,
            signer: address(0),
            startTime: uint32(block.timestamp),
            endTime: uint32(block.timestamp + 1000),
            maxTotalRedemptions: 5,
            manager: address(this)
        });

        offerer.updateCampaign(0, params, "");

        OfferItem[] memory offerFromEvent = new OfferItem[](1);
        offerFromEvent[0] = OfferItem({
            itemType: ItemType.ERC721,
            token: address(redemptionToken),
            identifierOrCriteria: tokenId,
            startAmount: 1,
            endAmount: 1
        });

        ConsiderationItem[]
            memory considerationFromEvent = new ConsiderationItem[](1);
        considerationFromEvent[0] = ConsiderationItem({
            itemType: ItemType.ERC721,
            token: address(redeemableToken),
            identifierOrCriteria: tokenId,
            startAmount: 1,
            endAmount: 1,
            recipient: payable(_BURN_ADDRESS)
        });

        uint256 campaignId = 1;
        bytes32 redemptionHash = bytes32(0);

        vm.expectEmit(true, true, true, true);
        emit Redemption(
            address(this),
            campaignId,
            ConsiderationItemLib.toSpentItemArray(considerationFromEvent),
            OfferItemLib.toSpentItemArray(offerFromEvent),
            redemptionHash
        );

        bytes memory data = abi.encode(campaignId, redemptionHash);
        redeemableToken.safeTransferFrom(
            address(this),
            address(offerer),
            tokenId,
            data
        );

        assertEq(redeemableToken.ownerOf(tokenId), _BURN_ADDRESS);
        assertEq(redemptionToken.ownerOf(tokenId), address(this));
    }

    function testRedeemWithSeaport() public {
        uint256 tokenId = 2;
        redeemableToken.mint(address(this), tokenId);
        redeemableToken.setApprovalForAll(address(seaport), true);

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
            recipient: payable(_BURN_ADDRESS)
        });

        {
            CampaignParams memory params = CampaignParams({
                offer: offer,
                consideration: consideration,
                signer: address(0),
                startTime: uint32(block.timestamp),
                endTime: uint32(block.timestamp + 1000),
                maxTotalRedemptions: 5,
                manager: address(this)
            });

            offerer.updateCampaign(0, params, "");
        }

        uint256 campaignId = 1;
        bytes32 redemptionHash = bytes32(0);

        {
            OfferItem[] memory offerFromEvent = new OfferItem[](1);
            offerFromEvent[0] = OfferItem({
                itemType: ItemType.ERC721,
                token: address(redemptionToken),
                identifierOrCriteria: tokenId,
                startAmount: 1,
                endAmount: 1
            });
            ConsiderationItem[]
                memory considerationFromEvent = new ConsiderationItem[](1);
            considerationFromEvent[0] = ConsiderationItem({
                itemType: ItemType.ERC721,
                token: address(redeemableToken),
                identifierOrCriteria: tokenId,
                startAmount: 1,
                endAmount: 1,
                recipient: payable(_BURN_ADDRESS)
            });

            vm.expectEmit(true, true, true, true);
            emit Redemption(
                address(this),
                campaignId,
                ConsiderationItemLib.toSpentItemArray(considerationFromEvent),
                OfferItemLib.toSpentItemArray(offerFromEvent),
                redemptionHash
            );

            assertGt(
                uint256(consideration[0].itemType),
                uint256(considerationFromEvent[0].itemType)
            );

            bytes memory extraData = abi.encode(campaignId, redemptionHash);
            consideration[0].identifierOrCriteria = tokenId;

            OrderParameters memory parameters = OrderParametersLib
                .empty()
                .withOfferer(address(offerer))
                .withOrderType(OrderType.CONTRACT)
                .withConsideration(considerationFromEvent)
                .withOffer(offer)
                .withStartTime(block.timestamp)
                .withEndTime(block.timestamp + 1)
                .withTotalOriginalConsiderationItems(consideration.length);
            AdvancedOrder memory order = AdvancedOrder({
                parameters: parameters,
                numerator: 1,
                denominator: 1,
                signature: "",
                extraData: extraData
            });

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

    // TODO: write test providing criteria resolver, success and failure case

    function testRevertMaxTotalRedemptionsReached() public {
        redeemableToken.mint(address(this), 0);
        redeemableToken.mint(address(this), 1);
        redeemableToken.mint(address(this), 2);
        redeemableToken.setApprovalForAll(address(seaport), true);

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
            recipient: payable(_BURN_ADDRESS)
        });

        {
            CampaignParams memory params = CampaignParams({
                offer: offer,
                consideration: consideration,
                signer: address(0),
                startTime: uint32(block.timestamp),
                endTime: uint32(block.timestamp + 1000),
                maxTotalRedemptions: 2,
                manager: address(this)
            });

            offerer.updateCampaign(0, params, "");
        }

        uint256 campaignId = 1;
        bytes32 redemptionHash = bytes32(0);

        {
            OfferItem[] memory offerFromEvent = new OfferItem[](1);
            offerFromEvent[0] = OfferItem({
                itemType: ItemType.ERC721,
                token: address(redemptionToken),
                identifierOrCriteria: 0,
                startAmount: 1,
                endAmount: 1
            });
            ConsiderationItem[]
                memory considerationFromEvent = new ConsiderationItem[](1);
            considerationFromEvent[0] = ConsiderationItem({
                itemType: ItemType.ERC721,
                token: address(redeemableToken),
                identifierOrCriteria: 0,
                startAmount: 1,
                endAmount: 1,
                recipient: payable(_BURN_ADDRESS)
            });

            vm.expectEmit(true, true, true, true);
            emit Redemption(
                address(this),
                campaignId,
                ConsiderationItemLib.toSpentItemArray(considerationFromEvent),
                OfferItemLib.toSpentItemArray(offerFromEvent),
                redemptionHash
            );

            offerFromEvent[0] = OfferItem({
                itemType: ItemType.ERC721,
                token: address(redemptionToken),
                identifierOrCriteria: 1,
                startAmount: 1,
                endAmount: 1
            });

            considerationFromEvent[0] = ConsiderationItem({
                itemType: ItemType.ERC721,
                token: address(redeemableToken),
                identifierOrCriteria: 1,
                startAmount: 1,
                endAmount: 1,
                recipient: payable(_BURN_ADDRESS)
            });

            assertGt(
                uint256(consideration[0].itemType),
                uint256(considerationFromEvent[0].itemType)
            );

            bytes memory extraData = abi.encode(campaignId, redemptionHash);

            considerationFromEvent[0].identifierOrCriteria = 0;

            OrderParameters memory parameters = OrderParametersLib
                .empty()
                .withOfferer(address(offerer))
                .withOrderType(OrderType.CONTRACT)
                .withConsideration(considerationFromEvent)
                .withOffer(offer)
                .withStartTime(block.timestamp)
                .withEndTime(block.timestamp + 1)
                .withTotalOriginalConsiderationItems(consideration.length);
            AdvancedOrder memory order = AdvancedOrder({
                parameters: parameters,
                numerator: 1,
                denominator: 1,
                signature: "",
                extraData: extraData
            });

            seaport.fulfillAdvancedOrder({
                advancedOrder: order,
                criteriaResolvers: criteriaResolvers,
                fulfillerConduitKey: bytes32(0),
                recipient: address(0)
            });

            considerationFromEvent[0].identifierOrCriteria = 1;

            vm.expectEmit(true, true, true, true);
            emit Redemption(
                address(this),
                campaignId,
                ConsiderationItemLib.toSpentItemArray(considerationFromEvent),
                OfferItemLib.toSpentItemArray(offerFromEvent),
                redemptionHash
            );

            seaport.fulfillAdvancedOrder({
                advancedOrder: order,
                criteriaResolvers: criteriaResolvers,
                fulfillerConduitKey: bytes32(0),
                recipient: address(0)
            });

            considerationFromEvent[0].identifierOrCriteria = 2;

            // Should revert on the third redemption
            vm.expectRevert(
                abi.encodeWithSelector(
                    MaxTotalRedemptionsReached.selector,
                    3,
                    2
                )
            );
            seaport.fulfillAdvancedOrder({
                advancedOrder: order,
                criteriaResolvers: criteriaResolvers,
                fulfillerConduitKey: bytes32(0),
                recipient: address(0)
            });

            assertEq(redeemableToken.ownerOf(0), _BURN_ADDRESS);
            assertEq(redeemableToken.ownerOf(1), _BURN_ADDRESS);
            assertEq(redemptionToken.ownerOf(0), address(this));
            assertEq(redemptionToken.ownerOf(1), address(this));
        }
    }

    function testRevertConsiderationItemRecipientCannotBeZeroAddress() public {
        uint256 tokenId = 2;
        redeemableToken.mint(address(this), tokenId);
        redeemableToken.setApprovalForAll(address(seaport), true);

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

        {
            CampaignParams memory params = CampaignParams({
                offer: offer,
                consideration: consideration,
                signer: address(0),
                startTime: uint32(block.timestamp),
                endTime: uint32(block.timestamp + 1000),
                maxTotalRedemptions: 5,
                manager: address(this)
            });

            vm.expectRevert(
                abi.encodeWithSelector(
                    ConsiderationItemRecipientCannotBeZeroAddress.selector
                )
            );
            offerer.updateCampaign(0, params, "");
        }
    }

    function xtestRedeemMultipleWithSeaport() public {
        uint256 tokenId;
        redeemableToken.setApprovalForAll(address(seaport), true);

        AdvancedOrder[] memory orders = new AdvancedOrder[](5);
        OfferItem[] memory offer = new OfferItem[](1);
        ConsiderationItem[] memory consideration = new ConsiderationItem[](1);

        uint256 campaignId = 1;
        bytes32 redemptionHash = bytes32(0);

        offer[0] = OfferItem({
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: address(redemptionToken),
            identifierOrCriteria: 0,
            startAmount: 1,
            endAmount: 1
        });

        consideration[0] = ConsiderationItem({
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: address(redeemableToken),
            identifierOrCriteria: 0,
            startAmount: 1,
            endAmount: 1,
            recipient: payable(_BURN_ADDRESS)
        });

        OrderParameters memory parameters = OrderParametersLib
            .empty()
            .withOfferer(address(offerer))
            .withOrderType(OrderType.CONTRACT)
            .withConsideration(consideration)
            .withOffer(offer)
            .withStartTime(block.timestamp)
            .withEndTime(block.timestamp + 1)
            .withTotalOriginalConsiderationItems(1);

        for (uint256 i; i < 5; i++) {
            tokenId = i;
            redeemableToken.mint(address(this), tokenId);

            bytes memory extraData = abi.encode(campaignId, redemptionHash);
            AdvancedOrder memory order = AdvancedOrder({
                parameters: parameters,
                numerator: 1,
                denominator: 1,
                signature: "",
                extraData: extraData
            });

            orders[i] = order;
        }

        CampaignParams memory params = CampaignParams({
            offer: offer,
            consideration: consideration,
            signer: address(0),
            startTime: uint32(block.timestamp),
            endTime: uint32(block.timestamp + 1000),
            maxTotalRedemptions: 5,
            manager: address(this)
        });

        offerer.updateCampaign(0, params, "");

        OfferItem[] memory offerFromEvent = new OfferItem[](1);
        offerFromEvent[0] = OfferItem({
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: address(redemptionToken),
            identifierOrCriteria: 0,
            startAmount: 1,
            endAmount: 1
        });

        ConsiderationItem[]
            memory considerationFromEvent = new ConsiderationItem[](1);
        considerationFromEvent[0] = ConsiderationItem({
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: address(redeemableToken),
            identifierOrCriteria: 0,
            startAmount: 1,
            endAmount: 1,
            recipient: payable(_BURN_ADDRESS)
        });

        vm.expectEmit(true, true, true, true);
        emit Redemption(
            address(this),
            campaignId,
            ConsiderationItemLib.toSpentItemArray(considerationFromEvent),
            OfferItemLib.toSpentItemArray(offerFromEvent),
            redemptionHash
        );

        (
            FulfillmentComponent[][] memory offerFulfillmentComponents,
            FulfillmentComponent[][] memory considerationFulfillmentComponents
        ) = fulfill.getNaiveFulfillmentComponents(orders);

        seaport.fulfillAvailableAdvancedOrders({
            advancedOrders: orders,
            criteriaResolvers: criteriaResolvers,
            offerFulfillments: offerFulfillmentComponents,
            considerationFulfillments: considerationFulfillmentComponents,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0),
            maximumFulfilled: 10
        });

        for (uint256 i; i < 5; i++) {
            tokenId = i;
            assertEq(redeemableToken.ownerOf(tokenId), _BURN_ADDRESS);
            assertEq(redemptionToken.ownerOf(tokenId), address(this));
        }
    }
}

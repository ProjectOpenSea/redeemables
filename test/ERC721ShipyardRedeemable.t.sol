// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Solarray} from "solarray/Solarray.sol";
import {ERC721} from "solady/src/tokens/ERC721.sol";
import {TestERC721} from "./utils/mocks/TestERC721.sol";
import {OfferItem, ConsiderationItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {ItemType, OrderType, Side} from "seaport-sol/src/SeaportEnums.sol";
import {CampaignParams, CampaignRequirements, TraitRedemption} from "../src/lib/RedeemablesStructs.sol";
import {RedeemablesErrors} from "../src/lib/RedeemablesErrors.sol";
import {ERC721RedemptionMintable} from "../src/lib/ERC721RedemptionMintable.sol";
import {ERC721ShipyardRedeemableMintable} from "../src/lib/ERC721ShipyardRedeemableMintable.sol";

contract TestERC721ShipyardRedeemable is RedeemablesErrors, Test {
    event Redemption(
        uint256 indexed campaignId,
        uint256 requirementsIndex,
        uint256[][] tokenIds,
        bytes32 redemptionHash,
        address redeemedBy
    );

    ERC721ShipyardRedeemableMintable redeemToken;
    ERC721RedemptionMintable receiveToken;
    address alice;

    address constant _BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    function setUp() public {
        redeemToken = new ERC721ShipyardRedeemableMintable();
        receiveToken = new ERC721RedemptionMintable(address(redeemToken));
        alice = makeAddr("alice");

        vm.label(address(redeemToken), "redeemToken");
        vm.label(address(receiveToken), "receiveToken");
        vm.label(alice, "alice");
    }

    function testBurnInternalToken() public {
        uint256 tokenId = 2;
        redeemToken.mint(address(this), tokenId);

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

        {
            CampaignParams memory params = CampaignParams({
                requirements: requirements,
                signer: address(0),
                startTime: uint32(block.timestamp),
                endTime: uint32(block.timestamp + 1000),
                maxCampaignRedemptions: 5,
                manager: address(this)
            });

            redeemToken.createCampaign(params, "");
        }

        {
            OfferItem[] memory offerFromEvent = new OfferItem[](1);
            offerFromEvent[0] = OfferItem({
                itemType: ItemType.ERC721,
                token: address(receiveToken),
                identifierOrCriteria: tokenId,
                startAmount: 1,
                endAmount: 1
            });
            ConsiderationItem[]
                memory considerationFromEvent = new ConsiderationItem[](1);
            considerationFromEvent[0] = ConsiderationItem({
                itemType: ItemType.ERC721,
                token: address(redeemToken),
                identifierOrCriteria: tokenId,
                startAmount: 1,
                endAmount: 1,
                recipient: payable(_BURN_ADDRESS)
            });

            assertGt(
                uint256(consideration[0].itemType),
                uint256(considerationFromEvent[0].itemType)
            );

            // campaignId: 1
            // requirementsIndex: 0
            // redemptionHash: bytes32(0)
            bytes memory extraData = abi.encode(1, 0, bytes32(0));
            consideration[0].identifierOrCriteria = tokenId;

            uint256[] memory tokenIds = Solarray.uint256s(tokenId);
            uint256[][] memory redemptions = new uint256[][](1);
            redemptions[0] = tokenIds;

            vm.expectEmit(true, true, true, true);
            emit Redemption(1, 0, redemptions, bytes32(0), address(this));
            redeemToken.redeem(redemptions, address(this), extraData);

            vm.expectRevert(ERC721.TokenDoesNotExist.selector);
            redeemToken.ownerOf(tokenId);

            assertEq(receiveToken.ownerOf(1), address(this));
        }
    }

    function testRevert721ConsiderationItemInsufficientBalance() public {
        uint256 tokenId = 2;
        uint256 invalidTokenId = tokenId + 1;
        redeemToken.mint(address(this), tokenId);
        redeemToken.mint(alice, invalidTokenId);

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

        {
            CampaignParams memory params = CampaignParams({
                requirements: requirements,
                signer: address(0),
                startTime: uint32(block.timestamp),
                endTime: uint32(block.timestamp + 1000),
                maxCampaignRedemptions: 5,
                manager: address(this)
            });

            redeemToken.createCampaign(params, "");
        }

        {
            OfferItem[] memory offerFromEvent = new OfferItem[](1);
            offerFromEvent[0] = OfferItem({
                itemType: ItemType.ERC721,
                token: address(receiveToken),
                identifierOrCriteria: tokenId,
                startAmount: 1,
                endAmount: 1
            });
            ConsiderationItem[]
                memory considerationFromEvent = new ConsiderationItem[](1);
            considerationFromEvent[0] = ConsiderationItem({
                itemType: ItemType.ERC721,
                token: address(redeemToken),
                identifierOrCriteria: tokenId,
                startAmount: 1,
                endAmount: 1,
                recipient: payable(_BURN_ADDRESS)
            });

            assertGt(
                uint256(consideration[0].itemType),
                uint256(considerationFromEvent[0].itemType)
            );

            // campaignId: 1
            // requirementsIndex: 0
            // redemptionHash: bytes32(0)
            bytes memory extraData = abi.encode(1, 0, bytes32(0));
            consideration[0].identifierOrCriteria = tokenId;

            uint256[] memory tokenIds = Solarray.uint256s(invalidTokenId);
            uint256[][] memory redemptions = new uint256[][](1);
            redemptions[0] = tokenIds;

            vm.expectRevert(
                abi.encodeWithSelector(
                    ConsiderationItemInsufficientBalance.selector,
                    requirements[0].consideration[0].token,
                    0,
                    requirements[0].consideration[0].startAmount
                )
            );
            redeemToken.redeem(redemptions, address(this), extraData);

            assertEq(redeemToken.ownerOf(tokenId), address(this));

            vm.expectRevert(ERC721.TokenDoesNotExist.selector);
            receiveToken.ownerOf(1);
        }
    }

    // requirements size: 1
    // testBurnWithoutConsiderationMet
    // testBurnWithoutConsiderationFullyMet

    // requirements size: 2
    // testBurnWithRequirementsIndexNotMet
    // testBurnWithSecondRequirementsIndex -> success case
}

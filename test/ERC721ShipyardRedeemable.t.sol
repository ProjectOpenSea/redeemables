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
    error InvalidContractOrder(bytes32 orderHash);

    ERC721ShipyardRedeemableMintable redeemToken;
    ERC721RedemptionMintable receiveToken;

    address constant _BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    function setUp() public {
        redeemToken = new ERC721ShipyardRedeemableMintable();
        receiveToken = new ERC721RedemptionMintable(
            address(redeemToken)
        );
        vm.label(address(redeemToken), "redeemToken");
        vm.label(address(receiveToken), "receiveToken");
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

        CampaignRequirements[] memory requirements = new CampaignRequirements[](1);
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
            ConsiderationItem[] memory considerationFromEvent = new ConsiderationItem[](1);
            considerationFromEvent[0] = ConsiderationItem({
                itemType: ItemType.ERC721,
                token: address(redeemToken),
                identifierOrCriteria: tokenId,
                startAmount: 1,
                endAmount: 1,
                recipient: payable(_BURN_ADDRESS)
            });

            assertGt(uint256(consideration[0].itemType), uint256(considerationFromEvent[0].itemType));

            // campaignId: 1
            // requirementsIndex: 0
            // redemptionHash: bytes32(0)
            bytes memory extraData = abi.encode(1, 0, bytes32(0));
            consideration[0].identifierOrCriteria = tokenId;

            uint256[] memory tokenIds = Solarray.uint256s(tokenId);
            uint256[][] memory redemptions = new uint256[][](1);
            redemptions[0] = tokenIds;

            redeemToken.redeem(redemptions, address(this), extraData);

            vm.expectRevert(ERC721.TokenDoesNotExist.selector);
            redeemToken.ownerOf(tokenId);

            assertEq(receiveToken.ownerOf(1), address(this));
        }
    }
}

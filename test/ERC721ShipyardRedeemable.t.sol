// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Solarray} from "solarray/Solarray.sol";
import {TestERC721} from "./utils/mocks/TestERC721.sol";
import {OfferItem, ConsiderationItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {ItemType, OrderType, Side} from "seaport-sol/src/SeaportEnums.sol";
import {CampaignParams, TraitRedemption} from "../src/lib/RedeemablesStructs.sol";
import {RedeemablesErrorsAndEvents} from "../src/lib/RedeemablesErrorsAndEvents.sol";
import {ERC721RedemptionMintable} from "../src/lib/ERC721RedemptionMintable.sol";
import {ERC721ShipyardRedeemable} from "../src/ERC721ShipyardRedeemable.sol";

contract ERC721ShipyardRedeemableMintable is ERC721ShipyardRedeemable {
    constructor() ERC721ShipyardRedeemable() {}

    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }
}

contract TestERC721ShipyardRedeemable is RedeemablesErrorsAndEvents, Test {
    error InvalidContractOrder(bytes32 orderHash);

    ERC721ShipyardRedeemableMintable redeemToken;
    ERC721RedemptionMintable receiveToken;

    address constant _BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    function setUp() public {
        redeemToken = new ERC721ShipyardRedeemableMintable();
        receiveToken = new ERC721RedemptionMintable(
            address(redeemToken),
            address(receiveToken)
        );
        vm.label(address(redeemToken), "redeemToken");
        vm.label(address(receiveToken), "receiveToken");
    }

    function testBurnInternalToken() public {
        uint256 tokenId = 2;
        redeemToken.mint(address(this), tokenId);

        redeemToken.setApprovalForAll(address(redeemToken), true);

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

        {
            CampaignParams memory params = CampaignParams({
                offer: offer,
                consideration: consideration,
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

            bytes memory extraData = abi.encode(1, bytes32(0)); // campaignId, redemptionHash
            consideration[0].identifierOrCriteria = tokenId;

            uint256[] memory tokenIds = new uint256[](1);
            tokenIds[0] = tokenId;

            redeemToken.redeem(tokenIds, address(this), extraData);

            assertEq(redeemToken.ownerOf(tokenId), _BURN_ADDRESS);
            assertEq(receiveToken.ownerOf(tokenId), address(this));
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {ItemType} from "seaport-types/src/lib/ConsiderationEnums.sol";
import {OfferItem, ConsiderationItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {IERC7496} from "shipyard-core/src/dynamic-traits/interfaces/IERC7496.sol";
import {Campaign, CampaignParams, CampaignRequirements, TraitRedemption} from "../src/lib/RedeemablesStructs.sol";
import {ERC721ShipyardRedeemableMintable} from "../src/extensions/ERC721ShipyardRedeemableMintable.sol";
import {ERC721ShipyardRedeemableTraitSetters} from "../src/test/ERC721ShipyardRedeemableTraitSetters.sol";

contract DeployAndRedeemTrait is Script, Test {
    function run() external {
        vm.startBroadcast();

        // deploy the receive token first
        ERC721ShipyardRedeemableMintable receiveToken = new ERC721ShipyardRedeemableMintable(
                "TestRedeemablesRecieveToken",
                "TEST"
            );

        // add the receive token address to allowed trait setters array
        address[] memory allowedTraitSetters = new address[](1);
        allowedTraitSetters[0] = address(receiveToken);

        // deploy the redeem token
        ERC721ShipyardRedeemableTraitSetters redeemToken = new ERC721ShipyardRedeemableTraitSetters(
                "DynamicTraitsRedeemToken",
                "TEST"
            );
        // set the receive token as an allowed trait setter
        redeemToken.setAllowedTraitSetters(allowedTraitSetters);

        // configure the campaign.
        OfferItem[] memory offer = new OfferItem[](1);

        // offer is receive token
        offer[0] = OfferItem({
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: address(receiveToken),
            identifierOrCriteria: 0,
            startAmount: 1,
            endAmount: 1
        });

        // consideration is empty
        ConsiderationItem[] memory consideration = new ConsiderationItem[](0);

        TraitRedemption[] memory traitRedemptions = new TraitRedemption[](1);

        // trait key is "hasRedeemed"
        bytes32 traitKey = bytes32("hasRedeemed");

        // previous trait value (`substandardValue`) should be 0
        bytes32 substandardValue = bytes32(uint256(0));

        // new trait value should be 1
        bytes32 traitValue = bytes32(uint256(1));

        traitRedemptions[0] = TraitRedemption({
            substandard: 1,
            token: address(redeemToken),
            traitKey: traitKey,
            traitValue: traitValue,
            substandardValue: substandardValue
        });

        CampaignRequirements[] memory requirements = new CampaignRequirements[](
            1
        );
        requirements[0].offer = offer;
        requirements[0].consideration = consideration;
        requirements[0].traitRedemptions = traitRedemptions;

        CampaignParams memory params = CampaignParams({
            startTime: uint32(block.timestamp),
            endTime: uint32(block.timestamp + 1_000_000),
            maxCampaignRedemptions: 1_000,
            manager: msg.sender,
            signer: address(0)
        });
        Campaign memory campaign = Campaign({params: params, requirements: requirements});
        receiveToken.createCampaign(campaign, "");

        // Mint token 1 to redeem for token 1.
        redeemToken.mint(msg.sender, 1);

        // Let's redeem them!
        uint256[] memory traitRedemptionTokenIds = new uint256[](1);
        traitRedemptionTokenIds[0] = 1;

        bytes memory data = abi.encode(
            1, // campaignId
            0, // requirementsIndex
            bytes32(0), // redemptionHash
            traitRedemptionTokenIds,
            uint256(0), // salt
            bytes("") // signature
        );

        receiveToken.redeem(new uint256[](0), msg.sender, data);

        // Assert new trait has been set and redemption token is minted.
        bytes32 actualTraitValue = IERC7496(address(redeemToken)).getTraitValue(1, traitKey);
        // "hasRedeemed" should be 1 (true)
        assertEq(bytes32(uint256(1)), actualTraitValue);
        assertEq(receiveToken.ownerOf(1), msg.sender);
    }
}

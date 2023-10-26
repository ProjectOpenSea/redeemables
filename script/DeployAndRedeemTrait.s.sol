// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {ItemType} from "seaport-types/src/lib/ConsiderationEnums.sol";
import {OfferItem, ConsiderationItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {DynamicTraits} from "shipyard-core/src/dynamic-traits/DynamicTraits.sol";
import {CampaignParams, CampaignRequirements, TraitRedemption} from "../src/lib/RedeemablesStructs.sol";
import {ERC721RedemptionMintable} from "../src/extensions/ERC721RedemptionMintable.sol";
import {ERC721ShipyardRedeemableMintable} from "../src/extensions/ERC721ShipyardRedeemableMintable.sol";
import {ERC721ShipyardRedeemablePreapprovedTraitSetters} from
    "../src/test/ERC721ShipyardRedeemablePreapprovedTraitSetters.sol";

contract DeployAndRedeemTrait is Script, Test {
    address constant _BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

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

        // deploy the redeem token with the receive token as an allowed trait setter
        ERC721ShipyardRedeemablePreapprovedTraitSetters redeemToken =
        new ERC721ShipyardRedeemablePreapprovedTraitSetters(
                "DynamicTraitsRedeemToken",
                "TEST",
                allowedTraitSetters
            );

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
        bytes32 traitKey = bytes32(bytes(string("hasRedeemed")));

        // previous trait value (`substandardValue`) should be 0
        bytes32 substandardValue = bytes32(uint256(0));

        // new trait value should be 1
        bytes32 traitValue = bytes32(uint256(1));

        traitRedemptions[0] = TraitRedemption({
            substandard: 1,
            token: address(redeemToken),
            identifier: 0, // unused field
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
            requirements: requirements,
            signer: address(0),
            startTime: uint32(block.timestamp),
            endTime: uint32(block.timestamp + 1_000_000),
            maxCampaignRedemptions: 1_000,
            manager: msg.sender
        });
        receiveToken.createCampaign(params, "");

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
            bytes("") // signer
        );

        receiveToken.redeem(new uint256[](0), msg.sender, data);

        // Assert new trait has been set and redemption token is minted.
        bytes32 actualTraitValue = DynamicTraits(address(redeemToken)).getTraitValue(1, traitKey);

        // "hasRedeemed" should be 1 (true)
        assertEq(bytes32(uint256(1)), actualTraitValue);

        assertEq(receiveToken.ownerOf(1), msg.sender);
    }
}

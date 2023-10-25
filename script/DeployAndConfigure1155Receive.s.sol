// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {ItemType} from "seaport-types/src/lib/ConsiderationEnums.sol";
import {OfferItem, ConsiderationItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {CampaignParams, CampaignRequirements} from "../src/lib/RedeemablesStructs.sol";
import {ERC721RedemptionMintable} from "../src/extensions/ERC721RedemptionMintable.sol";
import {ERC721OwnerMintable} from "../src/test/ERC721OwnerMintable.sol";
import {ERC1155ShipyardRedeemableMintable} from "../src/extensions/ERC1155ShipyardRedeemableMintable.sol";

contract DeployAndConfigure1155Receive is Script, Test {
    address constant _BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    function run() external {
        vm.startBroadcast();

        address redeemToken = 0x8fe638b493e1C548456F3E74B80D4Eb4ca4a1825;
        ERC1155ShipyardRedeemableMintable receiveToken = new ERC1155ShipyardRedeemableMintable(
                "ArbitrumTestReceiveToken1155",
                "ArbiTestReceive1155"
            );

        // Configure the campaign.
        OfferItem[] memory offer = new OfferItem[](3);
        offer[0] = OfferItem({
            itemType: ItemType.ERC1155_WITH_CRITERIA,
            token: address(receiveToken),
            identifierOrCriteria: 0,
            startAmount: 1,
            endAmount: 1
        });
        offer[1] = OfferItem({
            itemType: ItemType.ERC1155_WITH_CRITERIA,
            token: address(receiveToken),
            identifierOrCriteria: 0,
            startAmount: 1,
            endAmount: 1
        });
        offer[2] = OfferItem({
            itemType: ItemType.ERC1155_WITH_CRITERIA,
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

        CampaignParams memory params = CampaignParams({
            requirements: requirements,
            signer: address(0),
            startTime: 0,
            endTime: 0,
            maxCampaignRedemptions: 1_000,
            manager: msg.sender
        });
        uint256 campaignId =
            receiveToken.createCampaign(params, "ipfs://QmQjubc6guHReNW5Es5ZrgDtJRwXk2Aia7BkVoLJGaCRqP");

        receiveToken.setBaseURI("ipfs://QmWxgnz8T9wsMBmpCY4Cvanj3RR1obFD2hqDKPZhKN5Tsq/");

        // To test updateCampaign, update to proper start/end times.
        params.startTime = uint32(block.timestamp);
        params.endTime = uint32(block.timestamp + 10_000_000);
        receiveToken.updateCampaign(campaignId, params, "");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";

import {ItemType} from "seaport-types/src/lib/ConsiderationEnums.sol";
import {OfferItem, ConsiderationItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {RedeemableContractOffererV0} from "../src/RedeemableContractOffererV0.sol";
import {CampaignParamsV0} from "../src/lib/RedeemableStructs.sol";
import {ERC721RedemptionMintable} from "../src/lib/ERC721RedemptionMintable.sol";
import {TestERC721} from "../test/utils/mocks/TestERC721.sol";

contract DeployAndConfigureExampleCampaign is Script {
    // Addresses: Seaport
    address seaport = 0x00000000000000ADc04C56Bf30aC9d3c0aAF14dC;
    address conduit = 0x1E0049783F008A0085193E00003D00cd54003c71;

    address constant _BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    function run() external {
        vm.startBroadcast();

        RedeemableContractOffererV0 offerer = new RedeemableContractOffererV0(seaport);
        TestERC721 redeemableToken = new TestERC721();
        ERC721RedemptionMintable redemptionToken = new ERC721RedemptionMintable(address(offerer));

        // Configure the campaign.
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
            endTime: uint32(block.timestamp + 1_000_000),
            maxTotalRedemptions: 1_000,
            manager: address(this)
        });
        offerer.updateCampaign(0, params, "");

        // Mint tokens 1 and 5 to redeem for tokens 1 and 5.
        redeemableToken.mint(msg.sender, 1);
        redeemableToken.mint(msg.sender, 5);

        // Let's redeem them!
        uint256 campaignId = 1;
        bytes32 redemptionHash = bytes32(0);
        bytes memory data = abi.encode(campaignId, redemptionHash);
        redeemableToken.safeTransferFrom(msg.sender, address(offerer), 1, data);
        redeemableToken.safeTransferFrom(msg.sender, address(offerer), 5, data);
    }
}
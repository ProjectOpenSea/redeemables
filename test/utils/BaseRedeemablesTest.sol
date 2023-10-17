// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {BaseOrderTest} from "./BaseOrderTest.sol";
import {TestERC20} from "../utils/mocks/TestERC20.sol";
import {TestERC721} from "../utils/mocks/TestERC721.sol";
import {TestERC1155} from "../utils/mocks/TestERC1155.sol";
import {OfferItemLib, ConsiderationItemLib} from "seaport-sol/src/SeaportSol.sol";
import {OfferItem, ConsiderationItem} from "seaport-sol/src/SeaportStructs.sol";
import {ERC721RedemptionMintable} from "../../src/extensions/ERC721RedemptionMintable.sol";
import {ERC721ShipyardRedeemableOwnerMintable} from "../../src/test/ERC721ShipyardRedeemableOwnerMintable.sol";
import {RedeemablesErrors} from "../../src/lib/RedeemablesErrors.sol";
import {CampaignParams, CampaignRequirements, TraitRedemption} from "../../src/lib/RedeemablesStructs.sol";

contract BaseRedeemablesTest is RedeemablesErrors, BaseOrderTest {
    using OfferItemLib for OfferItem;
    using OfferItemLib for OfferItem[];
    using ConsiderationItemLib for ConsiderationItem;
    using ConsiderationItemLib for ConsiderationItem[];

    bytes32 private constant CAMPAIGN_PARAMS_MAP_POSITION = keccak256("CampaignParamsDefault");

    ERC721ShipyardRedeemableOwnerMintable redeemToken;
    ERC721RedemptionMintable receiveToken;

    OfferItem[] defaultCampaignOffer;
    ConsiderationItem[] defaultCampaignConsideration;
    TraitRedemption[] defaultTraitRedemptions;
    uint256[] defaultTraitRedemptionTokenIds = new uint256[](0);

    CampaignRequirements[] defaultCampaignRequirements;
    // CampaignParams defaultCampaignParams;

    address constant _BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    string constant DEFAULT_ERC721_CAMPAIGN_OFFER = "default erc721 campaign offer";
    string constant DEFAULT_ERC721_CAMPAIGN_CONSIDERATION = "default erc721 campaign consideration";

    function setUp() public virtual override {
        super.setUp();

        redeemToken = new ERC721ShipyardRedeemableOwnerMintable();
        receiveToken = new ERC721RedemptionMintable(address(redeemToken));

        vm.label(address(redeemToken), "redeemToken");
        vm.label(address(receiveToken), "receiveToken");

        // Save the default campaign offer and consideration
        OfferItemLib.fromDefault(SINGLE_ERC721).withToken(address(receiveToken)).saveDefault(
            DEFAULT_ERC721_CAMPAIGN_OFFER
        );

        ConsiderationItemLib.fromDefault(SINGLE_ERC721).withToken(address(redeemToken)).withRecipient(_BURN_ADDRESS)
            .saveDefault(DEFAULT_ERC721_CAMPAIGN_CONSIDERATION);

        defaultCampaignOffer.push(OfferItemLib.fromDefault(DEFAULT_ERC721_CAMPAIGN_OFFER));

        defaultCampaignConsideration.push(ConsiderationItemLib.fromDefault(DEFAULT_ERC721_CAMPAIGN_CONSIDERATION));
    }

    function _campaignParamsMap() private pure returns (mapping(string => CampaignParams) storage campaignParamsMap) {
        bytes32 position = CAMPAIGN_PARAMS_MAP_POSITION;
        assembly {
            campaignParamsMap.slot := position
        }
    }
}

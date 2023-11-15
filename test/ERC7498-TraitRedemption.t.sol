// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {BaseRedeemablesTest} from "./utils/BaseRedeemablesTest.sol";
import {Solarray} from "solarray/Solarray.sol";
import {IERC7496} from "shipyard-core/src/dynamic-traits/interfaces/IERC7496.sol";
import {OfferItem, ConsiderationItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {ItemType, OrderType, Side} from "seaport-sol/src/SeaportEnums.sol";
import {OfferItemLib} from "seaport-sol/src/lib/OfferItemLib.sol";
import {ConsiderationItemLib} from "seaport-sol/src/lib/ConsiderationItemLib.sol";
import {ERC721} from "solady/src/tokens/ERC721.sol";
import {IERC7496} from "shipyard-core/src/dynamic-traits/interfaces/IERC7496.sol";
import {IERC7498} from "../src/interfaces/IERC7498.sol";
import {Campaign, CampaignParams, CampaignRequirements, TraitRedemption} from "../src/lib/RedeemablesStructs.sol";
import {ERC721ShipyardRedeemableMintable} from "../src/extensions/ERC721ShipyardRedeemableMintable.sol";
import {ERC1155ShipyardRedeemableMintable} from "../src/extensions/ERC1155ShipyardRedeemableMintable.sol";
import {ERC721ShipyardRedeemableOwnerMintable} from "../src/test/ERC721ShipyardRedeemableOwnerMintable.sol";
import {ERC1155ShipyardRedeemableOwnerMintable} from "../src/test/ERC1155ShipyardRedeemableOwnerMintable.sol";
import {ERC721ShipyardRedeemableTraitSetters} from "../src/test/ERC721ShipyardRedeemableTraitSetters.sol";

contract ERC7498_TraitRedemption is BaseRedeemablesTest {
    using OfferItemLib for OfferItem;
    using OfferItemLib for OfferItem[];
    using ConsiderationItemLib for ConsiderationItem;
    using ConsiderationItemLib for ConsiderationItem[];

    uint256 tokenId = 2;
    bytes32 traitKey = bytes32("hasRedeemed");

    function testGetAndSetTrait() public {
        for (uint256 i; i < erc7498Tokens.length; i++) {
            testRedeemable(this.getAndSetTrait, RedeemablesContext({erc7498Token: IERC7498(erc7498Tokens[i])}));
        }
    }

    function getAndSetTrait(RedeemablesContext memory context) public {
        if (_isERC721(address(context.erc7498Token))) {
            vm.expectRevert(ERC721.TokenDoesNotExist.selector);
            IERC7496(address(context.erc7498Token)).getTraitValue(tokenId, traitKey);
            vm.expectRevert(ERC721.TokenDoesNotExist.selector);
            IERC7496(address(context.erc7498Token)).getTraitValues(tokenId, Solarray.bytes32s(traitKey));
        }

        _mintToken(address(context.erc7498Token), tokenId);
        bytes32 traitValue = IERC7496(address(context.erc7498Token)).getTraitValue(tokenId, traitKey);
        assertEq(traitValue, bytes32(0));

        IERC7496(address(context.erc7498Token)).setTrait(tokenId, traitKey, bytes32(uint256(1)));
        traitValue = IERC7496(address(context.erc7498Token)).getTraitValue(tokenId, traitKey);
        assertEq(traitValue, bytes32(uint256(1)));

        bytes32[] memory traitValues =
            IERC7496(address(context.erc7498Token)).getTraitValues(tokenId, Solarray.bytes32s(traitKey));
        assertEq(traitValues.length, 1);
        assertEq(traitValues[0], bytes32(uint256(1)));
    }

    function testErc721TraitRedemptionForErc721() public {
        for (uint256 i; i < erc7498Tokens.length; i++) {
            testRedeemable(
                this.erc721TraitRedemptionSubstandardOneForErc721,
                RedeemablesContext({erc7498Token: IERC7498(erc7498Tokens[i])})
            );
        }
    }

    function erc721TraitRedemptionSubstandardOneForErc721(RedeemablesContext memory context) public {
        address[] memory allowedTraitSetters = new address[](1);
        allowedTraitSetters[0] = address(context.erc7498Token);
        ERC721ShipyardRedeemableTraitSetters redeemToken = new ERC721ShipyardRedeemableTraitSetters(
                "",
                "",
                allowedTraitSetters
            );
        _mintToken(address(redeemToken), tokenId);
        TraitRedemption[] memory traitRedemptions = new TraitRedemption[](1);
        // previous trait value (`substandardValue`) should be 0
        // new trait value should be 1
        traitRedemptions[0] = TraitRedemption({
            substandard: 1,
            token: address(redeemToken),
            traitKey: traitKey,
            traitValue: bytes32(uint256(1)),
            substandardValue: bytes32(uint256(0))
        });
        CampaignRequirements[] memory requirements = new CampaignRequirements[](
            1
        );
        // consideration is empty
        ConsiderationItem[] memory consideration = new ConsiderationItem[](0);
        requirements[0] = CampaignRequirements({
            offer: defaultCampaignOffer,
            consideration: consideration,
            traitRedemptions: traitRedemptions
        });
        CampaignParams memory params = CampaignParams({
            startTime: uint32(block.timestamp),
            endTime: uint32(block.timestamp + 1000),
            maxCampaignRedemptions: 5,
            manager: address(this),
            signer: address(0)
        });
        Campaign memory campaign = Campaign({params: params, requirements: requirements});
        context.erc7498Token.createCampaign(campaign, "");

        uint256[] memory considerationTokenIds;
        // First test reverts with TraitRedemptionTokenIdsDontMatchTraitRedemptionsLength.
        uint256[] memory traitRedemptionTokenIds = Solarray.uint256s(tokenId, tokenId + 1);
        bytes memory extraData = abi.encode(
            1, // campaignId
            0, // requirementsIndex
            bytes32(0), // redemptionHash
            traitRedemptionTokenIds,
            uint256(0), // salt
            bytes("") // signature
        );

        vm.expectRevert(abi.encodeWithSelector(TraitRedemptionTokenIdsDontMatchTraitRedemptionsLength.selector, 1, 2));
        context.erc7498Token.redeem(considerationTokenIds, address(this), extraData);

        // Now test with valid trait redemptions token ids length.
        traitRedemptionTokenIds = Solarray.uint256s(tokenId);
        extraData = abi.encode(
            1, // campaignId
            0, // requirementsIndex
            bytes32(0), // redemptionHash
            traitRedemptionTokenIds,
            uint256(0), // salt
            bytes("") // signature
        );
        vm.expectEmit(true, true, true, true);
        emit Redemption(1, 0, bytes32(0), considerationTokenIds, traitRedemptionTokenIds, address(this));
        context.erc7498Token.redeem(considerationTokenIds, address(this), extraData);

        bytes32 actualTraitValue = redeemToken.getTraitValue(tokenId, traitKey);
        assertEq(bytes32(uint256(1)), actualTraitValue);
        assertEq(receiveToken721.ownerOf(1), address(this));

        // Redeeming one more time should fail with InvalidRequiredTraitValue since it is already 1.
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidRequiredTraitValue.selector, redeemToken, tokenId, traitKey, bytes32(uint256(1)), bytes32(0)
            )
        );
        context.erc7498Token.redeem(considerationTokenIds, address(this), extraData);
    }
}

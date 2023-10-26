// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {BaseRedeemablesTest} from "./utils/BaseRedeemablesTest.sol";
import {Solarray} from "solarray/Solarray.sol";
import {ERC721} from "solady/src/tokens/ERC721.sol";
import {TestERC20} from "./utils/mocks/TestERC20.sol";
import {TestERC721} from "./utils/mocks/TestERC721.sol";
import {TestERC1155} from "./utils/mocks/TestERC1155.sol";
import {IERC721A} from "seadrop/lib/ERC721A/contracts/IERC721A.sol";
import {IERC721} from "openzeppelin-contracts/contracts/interfaces/IERC721.sol";
import {IERC1155} from "openzeppelin-contracts/contracts/interfaces/IERC1155.sol";
import {IERC7498} from "../src/interfaces/IERC7498.sol";
import {DynamicTraits} from "shipyard-core/src/dynamic-traits/DynamicTraits.sol";
import {OfferItem, ConsiderationItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {ItemType, OrderType, Side} from "seaport-sol/src/SeaportEnums.sol";
import {OfferItemLib} from "seaport-sol/src/lib/OfferItemLib.sol";
import {ConsiderationItemLib} from "seaport-sol/src/lib/ConsiderationItemLib.sol";
import {CampaignParams, CampaignRequirements, TraitRedemption} from "../src/lib/RedeemablesStructs.sol";
import {ERC721RedemptionMintable} from "../src/extensions/ERC721RedemptionMintable.sol";
import {ERC721ShipyardRedeemableOwnerMintable} from "../src/test/ERC721ShipyardRedeemableOwnerMintable.sol";
import {ERC1155ShipyardRedeemableOwnerMintable} from "../src/test/ERC1155ShipyardRedeemableOwnerMintable.sol";
import {ERC721ShipyardRedeemablePreapprovedTraitSetters} from
    "../src/test/ERC721ShipyardRedeemablePreapprovedTraitSetters.sol";
import {ERC1155ShipyardRedeemableMintable} from "../src/extensions/ERC1155ShipyardRedeemableMintable.sol";

contract ERC7498_DynamicTraits is BaseRedeemablesTest {
    using OfferItemLib for OfferItem;
    using OfferItemLib for OfferItem[];
    using ConsiderationItemLib for ConsiderationItem;
    using ConsiderationItemLib for ConsiderationItem[];

    uint256 tokenId = 2;

    event Redemption(
        uint256 indexed campaignId,
        uint256 requirementsIndex,
        bytes32 redemptionHash,
        uint256[] considerationTokenIds,
        uint256[] traitRedemptionTokenIds,
        address redeemedBy
    );

    function setUp() public virtual override {
        super.setUp();
    }

    function testErc721TraitRedemptionForErc721() public {
        for (uint256 i; i < erc7498Tokens.length; i++) {
            bool isErc7498Token721 = _isErc7498Token721(address(erc7498Tokens[i]));

            bool isErc7498TokenSeaDrop = _isErc7498TokenSeaDrop(address(erc7498Tokens[i]));
            testRedeemable(
                this.erc721TraitRedemptionSubstandardOneForErc721,
                RedeemablesContext({
                    erc7498Token: IERC7498(erc7498Tokens[i]),
                    isErc7498Token721: isErc7498Token721,
                    isErc7498TokenSeaDrop: isErc7498TokenSeaDrop
                })
            );
        }
    }

    function erc721TraitRedemptionSubstandardOneForErc721(RedeemablesContext memory context) public {
        address[] memory allowedTraitSetters = new address[](1);
        allowedTraitSetters[0] = address(context.erc7498Token);

        ERC721ShipyardRedeemablePreapprovedTraitSetters redeemToken =
        new ERC721ShipyardRedeemablePreapprovedTraitSetters(
                "Test",
                "TEST",
                allowedTraitSetters
            );
        redeemToken.mint(address(this), tokenId);

        TraitRedemption[] memory traitRedemptions = new TraitRedemption[](1);

        // trait key is "hasRedeemed"
        bytes32 traitKey = bytes32(bytes(string("hasRedeemed")));

        // previous trait value (`substandardValue`) should be 0
        // new trait value should be 1
        traitRedemptions[0] = TraitRedemption({
            substandard: 1,
            token: address(redeemToken),
            identifier: 0, // unused field
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
            requirements: requirements,
            signer: address(0),
            startTime: uint32(block.timestamp),
            endTime: uint32(block.timestamp + 1000),
            maxCampaignRedemptions: 5,
            manager: address(this)
        });

        context.erc7498Token.createCampaign(params, "");

        uint256[] memory considerationTokenIds = new uint256[](0);
        uint256[] memory traitRedemptionTokenIds = Solarray.uint256s(tokenId);

        // campaignId: 1
        // requirementsIndex: 0
        // redemptionHash: bytes32(0)
        // traitRedemptionTokenIds: traitRedemptionTokenIds
        // salt: 0
        // signature: bytes(0)
        bytes memory extraData = abi.encode(1, 0, bytes32(0), traitRedemptionTokenIds, uint256(0), bytes(""));

        vm.expectEmit(true, true, true, true);
        emit Redemption(1, 0, bytes32(0), considerationTokenIds, traitRedemptionTokenIds, address(this));

        context.erc7498Token.redeem(considerationTokenIds, address(this), extraData);

        bytes32 actualTraitValue = DynamicTraits(address(redeemToken)).getTraitValue(tokenId, traitKey);

        assertEq(bytes32(uint256(1)), actualTraitValue);

        assertEq(IERC721(address(receiveToken721)).ownerOf(1), address(this));
    }
}

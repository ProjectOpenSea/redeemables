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
import {IERC7498} from "../../src/interfaces/IERC7498.sol";
import {OfferItem, ConsiderationItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {ItemType, OrderType, Side} from "seaport-sol/src/SeaportEnums.sol";
import {OfferItemLib} from "seaport-sol/src/lib/OfferItemLib.sol";
import {ConsiderationItemLib} from "seaport-sol/src/lib/ConsiderationItemLib.sol";
import {CampaignParams, CampaignRequirements, TraitRedemption} from "../src/lib/RedeemablesStructs.sol";
import {ERC721RedemptionMintable} from "../src/extensions/ERC721RedemptionMintable.sol";
import {ERC721ShipyardRedeemableOwnerMintable} from "../src/test/ERC721ShipyardRedeemableOwnerMintable.sol";
import {ERC1155ShipyardRedeemableOwnerMintable} from "../src/test/ERC1155ShipyardRedeemableOwnerMintable.sol";
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
        _mintToken(address(context.erc7498Token), tokenId, context.isErc7498Token721);

        TraitRedemption[] memory traitRedemptions = new TraitRedemption[](1);

        // trait key is "hasRedeemed"
        // previous trait value (`substandardValue`) should be 0
        // new trait value should be 1
        traitRedemptions[0] = TraitRedemption({
            substandard: 1,
            token: address(context.erc7498Token),
            identifier: tokenId,
            traitKey: bytes32(bytes(string("hasRedeemed"))),
            traitValue: bytes32(uint256(1)),
            substandardValue: bytes32(uint256(0))
        });

        ConsiderationItem[] memory consideration = new ConsiderationItem[](0);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {BaseRedeemablesTest} from "./utils/BaseRedeemablesTest.sol";
import {Solarray} from "solarray/Solarray.sol";
import {ERC721} from "solady/src/tokens/ERC721.sol";
import {IERC721A} from "seadrop/lib/ERC721A/contracts/IERC721A.sol";
import {IERC721} from "openzeppelin-contracts/contracts/interfaces/IERC721.sol";
import {IERC1155} from "openzeppelin-contracts/contracts/interfaces/IERC1155.sol";
import {IERC7498} from "../../src/interfaces/IERC7498.sol";
import {TestERC20} from "./utils/mocks/TestERC20.sol";
import {TestERC721} from "./utils/mocks/TestERC721.sol";
import {TestERC1155} from "./utils/mocks/TestERC1155.sol";
import {OfferItem, ConsiderationItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {ItemType, OrderType, Side} from "seaport-sol/src/SeaportEnums.sol";
import {OfferItemLib} from "seaport-sol/src/lib/OfferItemLib.sol";
import {ConsiderationItemLib} from "seaport-sol/src/lib/ConsiderationItemLib.sol";
import {CampaignParams, CampaignRequirements, TraitRedemption} from "../src/lib/RedeemablesStructs.sol";
import {ERC721RedemptionMintable} from "../src/extensions/ERC721RedemptionMintable.sol";
import {ERC721ShipyardRedeemableOwnerMintable} from "../src/test/ERC721ShipyardRedeemableOwnerMintable.sol";
import {ERC1155ShipyardRedeemableOwnerMintable} from "../src/test/ERC1155ShipyardRedeemableOwnerMintable.sol";
import {IERC7498} from "../src/interfaces/IERC7498.sol";

contract TestERC721ShipyardRedeemable is BaseRedeemablesTest {
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

    function testBurnErc721OrErc1155RedeemErc721() public {
        for (uint256 i; i < erc7498Tokens.length; i++) {
            testRedeemable(
                this.burnErc721OrErc1155RedeemErc721, RedeemablesContext({erc7498Token: IERC7498(erc7498Tokens[i])})
            );
        }
    }

    function burnErc721OrErc1155RedeemErc721(RedeemablesContext memory context) external {
        bool isErc7498Token721 = _isErc7498Token721(address(context.erc7498Token));

        bool isErc7498TokenSeaDrop = _isErc7498TokenSeaDrop(address(context.erc7498Token));

        if (isErc7498Token721) {
            ERC721ShipyardRedeemableOwnerMintable(address(context.erc7498Token)).mint(address(this), tokenId);
        } else {
            ERC1155ShipyardRedeemableOwnerMintable(address(context.erc7498Token)).mint(address(this), tokenId, 1);
        }

        ConsiderationItem[] memory consideration =
            _getCampaignConsideration(address(context.erc7498Token), isErc7498Token721);

        CampaignRequirements[] memory requirements = new CampaignRequirements[](
            1
        );

        requirements[0] = CampaignRequirements({
            offer: defaultCampaignOffer,
            consideration: consideration,
            traitRedemptions: defaultTraitRedemptions
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

        // campaignId: 1
        // requirementsIndex: 0
        // redemptionHash: bytes32(0)
        bytes memory extraData = abi.encode(1, 0, bytes32(0));

        uint256[] memory considerationTokenIds = Solarray.uint256s(tokenId);

        vm.expectEmit(true, true, true, true);
        emit Redemption(1, 0, bytes32(0), considerationTokenIds, defaultTraitRedemptionTokenIds, address(this));
        context.erc7498Token.redeem(considerationTokenIds, address(this), extraData);

        if (isErc7498Token721) {
            if (isErc7498TokenSeaDrop) {
                vm.expectRevert(IERC721A.OwnerQueryForNonexistentToken.selector);
            } else {
                vm.expectRevert(ERC721.TokenDoesNotExist.selector);
            }
            IERC721(address(context.erc7498Token)).ownerOf(tokenId);
        } else {
            // context.erc7498Token is ERC1155
            assertEq(IERC1155(address(context.erc7498Token)).balanceOf(address(this), tokenId), 0);
        }

        // TODO: update to receiveToken721
        assertEq(receiveToken721.ownerOf(1), address(this));
    }

    function testBurnErc721RedeemErc721WithSecondRequirementsIndex() public {
        ERC721ShipyardRedeemableOwnerMintable secondRedeemToken = new ERC721ShipyardRedeemableOwnerMintable(
                "",
                ""
            );
        vm.label(address(secondRedeemToken), "secondRedeemToken");
        secondRedeemToken.setApprovalForAll(address(erc7498Tokens[0]), true);

        ERC721ShipyardRedeemableOwnerMintable(erc7498Tokens[0]).mint(address(this), tokenId);
        secondRedeemToken.mint(address(this), tokenId);

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
            token: address(erc7498Tokens[0]),
            identifierOrCriteria: 0,
            startAmount: 1,
            endAmount: 1,
            recipient: payable(_BURN_ADDRESS)
        });

        ConsiderationItem[] memory secondRequirementConsideration = new ConsiderationItem[](1);
        secondRequirementConsideration[0] = ConsiderationItem({
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: address(secondRedeemToken),
            identifierOrCriteria: 0,
            startAmount: 1,
            endAmount: 1,
            recipient: payable(_BURN_ADDRESS)
        });

        CampaignRequirements[] memory requirements = new CampaignRequirements[](
            2
        );
        requirements[0].offer = offer;
        requirements[0].consideration = consideration;

        requirements[1].offer = offer;
        requirements[1].consideration = secondRequirementConsideration;

        CampaignParams memory params = CampaignParams({
            requirements: requirements,
            signer: address(0),
            startTime: uint32(block.timestamp),
            endTime: uint32(block.timestamp + 1000),
            maxCampaignRedemptions: 5,
            manager: address(this)
        });

        IERC7498(erc7498Tokens[0]).createCampaign(params, "");

        // campaignId: 1
        // requirementsIndex: 0
        // redemptionHash: bytes32(0)
        bytes memory extraData = abi.encode(1, 1, bytes32(0));
        consideration[0].identifierOrCriteria = tokenId;

        uint256[] memory tokenIds = Solarray.uint256s(tokenId);

        IERC7498(erc7498Tokens[0]).redeem(tokenIds, address(this), extraData);

        assertEq(IERC721(erc7498Tokens[0]).ownerOf(tokenId), address(this));

        assertEq(secondRedeemToken.ownerOf(tokenId), _BURN_ADDRESS);

        assertEq(receiveToken.ownerOf(1), address(this));
    }

    function testBurnErc20RedeemErc721() public {
        erc20s[0].mint(address(this), 0.5 ether);

        CampaignRequirements[] memory requirements = new CampaignRequirements[](
            1
        );

        ConsiderationItem[] memory consideration = new ConsiderationItem[](1);
        consideration[0] = defaultCampaignConsideration[0].withToken(address(erc20s[0])).withItemType(ItemType.ERC20)
            .withStartAmount(0.5 ether).withEndAmount(0.5 ether);

        requirements[0] = CampaignRequirements({
            offer: defaultCampaignOffer,
            consideration: consideration,
            traitRedemptions: defaultTraitRedemptions
        });

        CampaignParams memory params = CampaignParams({
            requirements: requirements,
            signer: address(0),
            startTime: uint32(block.timestamp),
            endTime: uint32(block.timestamp + 1000),
            maxCampaignRedemptions: 5,
            manager: address(this)
        });

        IERC7498(erc7498Tokens[0]).createCampaign(params, "");

        // campaignId: 1
        // requirementsIndex: 0
        // redemptionHash: bytes32(0)
        bytes memory extraData = abi.encode(1, 0, bytes32(0));

        uint256[] memory considerationTokenIds = Solarray.uint256s(0);

        vm.expectEmit(true, true, true, true);
        emit Redemption(1, 0, bytes32(0), considerationTokenIds, defaultTraitRedemptionTokenIds, address(this));
        IERC7498(erc7498Tokens[0]).redeem(considerationTokenIds, address(this), extraData);

        vm.expectRevert(ERC721.TokenDoesNotExist.selector);
        IERC721(erc7498Tokens[0]).ownerOf(tokenId);

        assertEq(receiveToken721.ownerOf(1), address(this));
    }

    function testBurnErc721RedeemErc1155() public {
        ERC721ShipyardRedeemableOwnerMintable(erc7498Tokens[0]).mint(address(this), tokenId);

        CampaignRequirements[] memory requirements = new CampaignRequirements[](
            1
        );

        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = defaultCampaignOffer[0].withItemType(ItemType.ERC1155).withToken(address(receiveToken1155));

        requirements[0] = CampaignRequirements({
            offer: offer,
            consideration: defaultCampaignConsideration,
            traitRedemptions: defaultTraitRedemptions
        });

        CampaignParams memory params = CampaignParams({
            requirements: requirements,
            signer: address(0),
            startTime: uint32(block.timestamp),
            endTime: uint32(block.timestamp + 1000),
            maxCampaignRedemptions: 5,
            manager: address(this)
        });

        IERC7498(erc7498Tokens[0]).createCampaign(params, "");

        // campaignId: 1
        // requirementsIndex: 0
        // redemptionHash: bytes32(0)
        bytes memory extraData = abi.encode(1, 0, bytes32(0));

        uint256[] memory considerationTokenIds = Solarray.uint256s(tokenId);

        vm.expectEmit(true, true, true, true);
        emit Redemption(1, 0, bytes32(0), considerationTokenIds, defaultTraitRedemptionTokenIds, address(this));
        IERC7498(erc7498Tokens[0]).redeem(considerationTokenIds, address(this), extraData);

        vm.expectRevert(ERC721.TokenDoesNotExist.selector);
        IERC721(erc7498Tokens[0]).ownerOf(tokenId);

        assertEq(receiveToken1155.balanceOf(address(this), 0), 1);
    }
}
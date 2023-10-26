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

contract ERC7498_SimpleRedeem is BaseRedeemablesTest {
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
            bool isErc7498Token721 = _isErc7498Token721(address(erc7498Tokens[i]));

            bool isErc7498TokenSeaDrop = _isErc7498TokenSeaDrop(address(erc7498Tokens[i]));
            testRedeemable(
                this.burnErc721OrErc1155RedeemErc721,
                RedeemablesContext({
                    erc7498Token: IERC7498(erc7498Tokens[i]),
                    isErc7498Token721: isErc7498Token721,
                    isErc7498TokenSeaDrop: isErc7498TokenSeaDrop
                })
            );
        }
    }

    function burnErc721OrErc1155RedeemErc721(RedeemablesContext memory context) external {
        if (context.isErc7498Token721) {
            ERC721ShipyardRedeemableOwnerMintable(address(context.erc7498Token)).mint(address(this), tokenId);
        } else {
            ERC1155ShipyardRedeemableOwnerMintable(address(context.erc7498Token)).mint(address(this), tokenId, 1);
        }

        ConsiderationItem[] memory consideration = new ConsiderationItem[](1);
        consideration[0] = _getCampaignConsiderationItem(address(context.erc7498Token), context.isErc7498Token721);

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
        bytes memory extraData = abi.encode(1, 0, bytes32(0), defaultTraitRedemptionTokenIds, uint256(0), bytes(""));

        uint256[] memory considerationTokenIds = Solarray.uint256s(tokenId);

        vm.expectEmit(true, true, true, true);
        emit Redemption(1, 0, bytes32(0), considerationTokenIds, defaultTraitRedemptionTokenIds, address(this));
        context.erc7498Token.redeem(considerationTokenIds, address(this), extraData);

        _checkTokenDoesNotExist(
            address(context.erc7498Token), tokenId, context.isErc7498Token721, context.isErc7498TokenSeaDrop
        );

        assertEq(receiveToken721.ownerOf(1), address(this));
    }

    function testBurnErc721RedeemErc721WithSecondRequirementsIndex() public {
        for (uint256 i; i < erc7498Tokens.length; i++) {
            bool isErc7498Token721 = _isErc7498Token721(address(erc7498Tokens[i]));

            bool isErc7498TokenSeaDrop = _isErc7498TokenSeaDrop(address(erc7498Tokens[i]));
            testRedeemable(
                this.burnErc721OrErc1155RedeemErc721WithSecondRequirementsIndex,
                RedeemablesContext({
                    erc7498Token: IERC7498(erc7498Tokens[i]),
                    isErc7498Token721: isErc7498Token721,
                    isErc7498TokenSeaDrop: isErc7498TokenSeaDrop
                })
            );
        }
    }

    function burnErc721OrErc1155RedeemErc721WithSecondRequirementsIndex(RedeemablesContext memory context) public {
        ERC721ShipyardRedeemableOwnerMintable firstRequirementRedeemToken = new ERC721ShipyardRedeemableOwnerMintable(
                "",
                ""
            );
        vm.label(address(firstRequirementRedeemToken), "firstRequirementRedeemToken");
        firstRequirementRedeemToken.setApprovalForAll(address(context.erc7498Token), true);

        if (context.isErc7498Token721) {
            ERC721ShipyardRedeemableOwnerMintable(address(context.erc7498Token)).mint(address(this), tokenId);
        } else {
            ERC1155ShipyardRedeemableOwnerMintable(address(context.erc7498Token)).mint(address(this), tokenId, 1);
        }

        firstRequirementRedeemToken.mint(address(this), tokenId);

        ConsiderationItem[] memory firstRequirementConsideration = new ConsiderationItem[](1);
        firstRequirementConsideration[0] = ConsiderationItem({
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: address(firstRequirementRedeemToken),
            identifierOrCriteria: 0,
            startAmount: 1,
            endAmount: 1,
            recipient: payable(_BURN_ADDRESS)
        });

        ConsiderationItem[] memory secondRequirementConsideration = new ConsiderationItem[](1);
        secondRequirementConsideration[0] =
            _getCampaignConsiderationItem(address(context.erc7498Token), context.isErc7498Token721);

        CampaignRequirements[] memory requirements = new CampaignRequirements[](
            2
        );
        requirements[0] = CampaignRequirements({
            offer: defaultCampaignOffer,
            consideration: firstRequirementConsideration,
            traitRedemptions: defaultTraitRedemptions
        });

        requirements[1] = CampaignRequirements({
            offer: defaultCampaignOffer,
            consideration: secondRequirementConsideration,
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

        IERC7498(context.erc7498Token).createCampaign(params, "");

        // campaignId: 1
        // requirementsIndex: 0
        // redemptionHash: bytes32(0)
        bytes memory extraData = abi.encode(1, 0, bytes32(0), defaultTraitRedemptionTokenIds, uint256(0), bytes(""));

        uint256[] memory tokenIds = Solarray.uint256s(tokenId);

        IERC7498(context.erc7498Token).redeem(tokenIds, address(this), extraData);

        _checkTokenDoesNotExist(
            address(context.erc7498Token), tokenId, context.isErc7498Token721, context.isErc7498TokenSeaDrop
        );

        assertEq(firstRequirementRedeemToken.ownerOf(tokenId), address(this));

        assertEq(receiveToken721.ownerOf(1), address(this));
    }

    function testBurnErc20RedeemErc721() public {
        for (uint256 i; i < erc7498Tokens.length; i++) {
            bool isErc7498Token721 = _isErc7498Token721(address(erc7498Tokens[i]));

            bool isErc7498TokenSeaDrop = _isErc7498TokenSeaDrop(address(erc7498Tokens[i]));
            testRedeemable(
                this.burnErc20RedeemErc721,
                RedeemablesContext({
                    erc7498Token: IERC7498(erc7498Tokens[i]),
                    isErc7498Token721: isErc7498Token721,
                    isErc7498TokenSeaDrop: isErc7498TokenSeaDrop
                })
            );
        }
    }

    function burnErc20RedeemErc721(RedeemablesContext memory context) public {
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
        bytes memory extraData = abi.encode(1, 0, bytes32(0), defaultTraitRedemptionTokenIds, uint256(0), bytes(""));

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
        bytes memory extraData = abi.encode(1, 0, bytes32(0), defaultTraitRedemptionTokenIds, uint256(0), bytes(""));

        uint256[] memory considerationTokenIds = Solarray.uint256s(tokenId);

        vm.expectEmit(true, true, true, true);
        emit Redemption(1, 0, bytes32(0), considerationTokenIds, defaultTraitRedemptionTokenIds, address(this));
        IERC7498(erc7498Tokens[0]).redeem(considerationTokenIds, address(this), extraData);

        vm.expectRevert(ERC721.TokenDoesNotExist.selector);
        IERC721(erc7498Tokens[0]).ownerOf(tokenId);

        assertEq(receiveToken1155.balanceOf(address(this), 1), 1);
    }
}

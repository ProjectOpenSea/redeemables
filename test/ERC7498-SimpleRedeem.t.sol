// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {BaseRedeemablesTest} from "./utils/BaseRedeemablesTest.sol";
import {Solarray} from "solarray/Solarray.sol";
import {ERC721} from "solady/src/tokens/ERC721.sol";
import {IERC721} from "openzeppelin-contracts/contracts/interfaces/IERC721.sol";
import {OfferItem, ConsiderationItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {ItemType, OrderType, Side} from "seaport-sol/src/SeaportEnums.sol";
import {OfferItemLib} from "seaport-sol/src/lib/OfferItemLib.sol";
import {ConsiderationItemLib} from "seaport-sol/src/lib/ConsiderationItemLib.sol";
import {IERC7498} from "../src/interfaces/IERC7498.sol";
import {BURN_ADDRESS} from "../src/lib/RedeemablesConstants.sol";
import {Campaign, CampaignParams, CampaignRequirements} from "../src/lib/RedeemablesStructs.sol";
import {ERC721ShipyardRedeemableOwnerMintable} from "../src/test/ERC721ShipyardRedeemableOwnerMintable.sol";

contract ERC7498_SimpleRedeem is BaseRedeemablesTest {
    using OfferItemLib for OfferItem;
    using OfferItemLib for OfferItem[];
    using ConsiderationItemLib for ConsiderationItem;
    using ConsiderationItemLib for ConsiderationItem[];

    uint256 tokenId = 2;

    function testBurnErc721OrErc1155RedeemErc721() public {
        for (uint256 i; i < erc7498Tokens.length; i++) {
            testRedeemable(
                this.burnErc721OrErc1155RedeemErc721, RedeemablesContext({erc7498Token: IERC7498(erc7498Tokens[i])})
            );
        }
    }

    function burnErc721OrErc1155RedeemErc721(RedeemablesContext memory context) external {
        _mintToken(address(context.erc7498Token), tokenId);
        ConsiderationItem[] memory consideration = new ConsiderationItem[](1);
        consideration[0] = _getCampaignConsiderationItem(address(context.erc7498Token));
        CampaignRequirements[] memory requirements = new CampaignRequirements[](
            1
        );
        requirements[0] = CampaignRequirements({
            offer: defaultCampaignOffer,
            consideration: consideration,
            traitRedemptions: defaultTraitRedemptions
        });
        CampaignParams memory params = CampaignParams({
            startTime: 0,
            endTime: 0, // will revert with NotActive until updated
            maxCampaignRedemptions: 1,
            manager: address(this),
            signer: address(0)
        });
        Campaign memory campaign = Campaign({params: params, requirements: requirements});
        uint256 campaignId = context.erc7498Token.createCampaign(campaign, "");

        (,, uint256 totalRedemptionsPreRedeem) = context.erc7498Token.getCampaign(1);
        assertEq(totalRedemptionsPreRedeem, 0);

        bytes memory extraData = abi.encode(
            1, // campaignId
            0, // requirementsIndex
            bytes32(0), // redemptionHash
            defaultTraitRedemptionTokenIds,
            uint256(0), // salt
            bytes("") // signature
        );
        uint256[] memory considerationTokenIds = Solarray.uint256s(tokenId);

        vm.expectRevert(
            abi.encodeWithSelector(
                NotActive_.selector, block.timestamp, campaign.params.startTime, campaign.params.endTime
            )
        );
        context.erc7498Token.redeem(considerationTokenIds, address(0), extraData);

        // Update the campaign to an active endTime.
        campaign.params.endTime = uint32(block.timestamp + 1000);
        context.erc7498Token.updateCampaign(campaignId, campaign, "");

        // Clear the receiveToken mintRedemption allowed callers to check for error coverage.
        receiveToken721.setRedeemablesContracts(new address[](0));
        vm.expectRevert(abi.encodeWithSelector(InvalidCaller.selector, address(context.erc7498Token)));
        context.erc7498Token.redeem(considerationTokenIds, address(0), extraData);
        // Re-add allowed callers
        receiveToken721.setRedeemablesContracts(erc7498Tokens);

        vm.expectEmit(true, true, true, true);
        emit Redemption(1, 0, bytes32(0), considerationTokenIds, defaultTraitRedemptionTokenIds, address(this));
        // Using address(0) for recipient should assign to msg.sender.
        context.erc7498Token.redeem(considerationTokenIds, address(0), extraData);

        _checkTokenDoesNotExist(address(context.erc7498Token), tokenId);
        assertEq(receiveToken721.ownerOf(1), address(this));
        (,, uint256 totalRedemptionsPostRedeem) = context.erc7498Token.getCampaign(1);
        assertEq(totalRedemptionsPostRedeem, 1);

        // Redeeming one more should exceed maxCampaignRedemptions of 1.
        tokenId = 3;
        _mintToken(address(context.erc7498Token), tokenId);
        considerationTokenIds[0] = tokenId;
        vm.expectRevert(abi.encodeWithSelector(MaxCampaignRedemptionsReached.selector, 2, 1));
        context.erc7498Token.redeem(considerationTokenIds, address(0), extraData);
        // Reset tokenId back to its original value.
        tokenId = 2;
    }

    function testSendErc721OrErc1155RedeemErc721() public {
        for (uint256 i; i < erc7498Tokens.length; i++) {
            testRedeemable(
                this.sendErc721OrErc1155RedeemErc721, RedeemablesContext({erc7498Token: IERC7498(erc7498Tokens[i])})
            );
        }
    }

    function sendErc721OrErc1155RedeemErc721(RedeemablesContext memory context) external {
        _mintToken(address(context.erc7498Token), tokenId);
        ConsiderationItem[] memory consideration = new ConsiderationItem[](1);
        consideration[0] = _getCampaignConsiderationItem(address(context.erc7498Token));
        // Set consideration recipient to greg.
        address greg = makeAddr("greg");
        consideration[0].recipient = payable(greg);
        CampaignRequirements[] memory requirements = new CampaignRequirements[](
            1
        );
        requirements[0] = CampaignRequirements({
            offer: defaultCampaignOffer,
            consideration: consideration,
            traitRedemptions: defaultTraitRedemptions
        });
        CampaignParams memory params = CampaignParams({
            startTime: uint32(block.timestamp),
            endTime: uint32(block.timestamp + 1000),
            maxCampaignRedemptions: 1,
            manager: address(this),
            signer: address(0)
        });
        Campaign memory campaign = Campaign({params: params, requirements: requirements});
        context.erc7498Token.createCampaign(campaign, "");

        // Grant approval to the erc7498Token.
        IERC721(address(context.erc7498Token)).setApprovalForAll(address(context.erc7498Token), true);

        bytes memory extraData = abi.encode(
            1, // campaignId
            0, // requirementsIndex
            bytes32(0), // redemptionHash
            defaultTraitRedemptionTokenIds,
            uint256(0), // salt
            bytes("") // signature
        );
        uint256[] memory considerationTokenIds = Solarray.uint256s(tokenId);
        vm.expectEmit(true, true, true, true);
        emit Redemption(1, 0, bytes32(0), considerationTokenIds, defaultTraitRedemptionTokenIds, address(this));
        context.erc7498Token.redeem(considerationTokenIds, address(0), extraData);

        _checkTokenIsOwnedBy(address(context.erc7498Token), tokenId, greg);
        assertEq(receiveToken721.ownerOf(1), address(this));
    }

    function testBurnErc721RedeemErc721WithSecondRequirementsIndex() public {
        for (uint256 i; i < erc7498Tokens.length; i++) {
            testRedeemable(
                this.burnErc721OrErc1155RedeemErc721WithSecondRequirementsIndex,
                RedeemablesContext({erc7498Token: IERC7498(erc7498Tokens[i])})
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

        _mintToken(address(context.erc7498Token), tokenId);
        _mintToken(address(firstRequirementRedeemToken), tokenId);

        ConsiderationItem[] memory firstRequirementConsideration = new ConsiderationItem[](1);
        firstRequirementConsideration[0] = ConsiderationItem({
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: address(firstRequirementRedeemToken),
            identifierOrCriteria: 0,
            startAmount: 1,
            endAmount: 1,
            recipient: payable(BURN_ADDRESS)
        });
        ConsiderationItem[] memory secondRequirementConsideration = new ConsiderationItem[](1);
        secondRequirementConsideration[0] = _getCampaignConsiderationItem(address(context.erc7498Token));
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
            startTime: uint32(block.timestamp),
            endTime: uint32(block.timestamp + 1000),
            maxCampaignRedemptions: 5,
            manager: address(this),
            signer: address(0)
        });
        Campaign memory campaign = Campaign({params: params, requirements: requirements});
        context.erc7498Token.createCampaign(campaign, "");

        // Redeeming with an invalid requirementsIndex should revert.
        vm.expectRevert(RequirementsIndexOutOfBounds.selector);
        bytes memory extraData = abi.encode(
            1, // campaignId
            3, // requirementsIndex
            bytes32(0), // redemptionHash
            defaultTraitRedemptionTokenIds,
            uint256(0), // salt
            bytes("") // signature
        );
        uint256[] memory tokenIds = Solarray.uint256s(tokenId);
        context.erc7498Token.redeem(tokenIds, address(this), extraData);

        // Valid requirementsIndex should succeed.
        extraData = abi.encode(
            1, // campaignId
            1, // requirementsIndex
            bytes32(0), // redemptionHash
            defaultTraitRedemptionTokenIds,
            uint256(0), // salt
            bytes("") // signature
        );
        context.erc7498Token.redeem(tokenIds, address(this), extraData);

        _checkTokenDoesNotExist(address(context.erc7498Token), tokenId);
        assertEq(firstRequirementRedeemToken.ownerOf(tokenId), address(this));
        assertEq(receiveToken721.ownerOf(1), address(this));
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
            startTime: uint32(block.timestamp),
            endTime: uint32(block.timestamp + 1000),
            maxCampaignRedemptions: 5,
            manager: address(this),
            signer: address(0)
        });
        Campaign memory campaign = Campaign({params: params, requirements: requirements});
        IERC7498(erc7498Tokens[0]).createCampaign(campaign, "");

        bytes memory extraData = abi.encode(
            1, // campaignId
            0, // requirementsIndex
            bytes32(0), // redemptionHash
            defaultTraitRedemptionTokenIds,
            uint256(0), // salt
            bytes("") // signature
        );

        uint256[] memory considerationTokenIds = Solarray.uint256s(0);

        vm.expectEmit(true, true, true, true);
        emit Redemption(1, 0, bytes32(0), considerationTokenIds, defaultTraitRedemptionTokenIds, address(this));
        IERC7498(erc7498Tokens[0]).redeem(considerationTokenIds, address(this), extraData);

        vm.expectRevert(ERC721.TokenDoesNotExist.selector);
        IERC721(erc7498Tokens[0]).ownerOf(tokenId);
        assertEq(receiveToken721.ownerOf(1), address(this));
    }

    function testSendErc20RedeemErc721() public {
        erc20s[0].mint(address(this), 0.5 ether);
        CampaignRequirements[] memory requirements = new CampaignRequirements[](
            1
        );
        ConsiderationItem[] memory consideration = new ConsiderationItem[](1);
        consideration[0] = defaultCampaignConsideration[0].withToken(address(erc20s[0])).withItemType(ItemType.ERC20)
            .withStartAmount(0.5 ether).withEndAmount(0.5 ether);
        // Set consideration recipient to greg.
        address greg = makeAddr("greg");
        consideration[0].recipient = payable(greg);
        requirements[0] = CampaignRequirements({
            offer: defaultCampaignOffer,
            consideration: consideration,
            traitRedemptions: defaultTraitRedemptions
        });
        CampaignParams memory params = CampaignParams({
            startTime: uint32(block.timestamp),
            endTime: uint32(block.timestamp + 1000),
            maxCampaignRedemptions: 5,
            manager: address(this),
            signer: address(0)
        });
        Campaign memory campaign = Campaign({params: params, requirements: requirements});
        IERC7498(erc7498Tokens[0]).createCampaign(campaign, "");

        bytes memory extraData = abi.encode(
            1, // campaignId
            0, // requirementsIndex
            bytes32(0), // redemptionHash
            defaultTraitRedemptionTokenIds,
            uint256(0), // salt
            bytes("") // signature
        );

        uint256[] memory considerationTokenIds = Solarray.uint256s(0);

        vm.expectEmit(true, true, true, true);
        emit Redemption(1, 0, bytes32(0), considerationTokenIds, defaultTraitRedemptionTokenIds, address(this));
        IERC7498(erc7498Tokens[0]).redeem(considerationTokenIds, address(this), extraData);

        _checkTokenIsOwnedBy(address(erc20s[0]), tokenId, greg);
        assertEq(receiveToken721.ownerOf(1), address(this));
    }

    function testBurnErc721RedeemErc1155() public {
        _mintToken(address(erc7498Tokens[0]), tokenId);
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
            startTime: uint32(block.timestamp),
            endTime: uint32(block.timestamp + 1000),
            maxCampaignRedemptions: 5,
            manager: address(this),
            signer: address(0)
        });
        Campaign memory campaign = Campaign({params: params, requirements: requirements});
        IERC7498(erc7498Tokens[0]).createCampaign(campaign, "");

        bytes memory extraData = abi.encode(
            1, // campaignId
            0, // requirementsIndex
            bytes32(0), // redemptionHash
            defaultTraitRedemptionTokenIds,
            uint256(0), // salt
            bytes("") // signature
        );
        uint256[] memory considerationTokenIds = Solarray.uint256s(tokenId);

        // Clear the receiveToken mintRedemption allowed callers to check for error coverage.
        receiveToken1155.setRedeemablesContracts(new address[](0));
        vm.expectRevert(abi.encodeWithSelector(InvalidCaller.selector, erc7498Tokens[0]));
        IERC7498(erc7498Tokens[0]).redeem(considerationTokenIds, address(0), extraData);
        // Re-add allowed callers
        receiveToken1155.setRedeemablesContracts(erc7498Tokens);

        vm.expectEmit(true, true, true, true);
        emit Redemption(1, 0, bytes32(0), considerationTokenIds, defaultTraitRedemptionTokenIds, address(this));
        IERC7498(erc7498Tokens[0]).redeem(considerationTokenIds, address(this), extraData);

        vm.expectRevert(ERC721.TokenDoesNotExist.selector);
        IERC721(erc7498Tokens[0]).ownerOf(tokenId);
        assertEq(receiveToken1155.balanceOf(address(this), 1), 1);
    }
}

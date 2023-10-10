// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {BaseRedeemablesTest} from "./utils/BaseRedeemablesTest.sol";
import {Solarray} from "solarray/Solarray.sol";
import {ERC721} from "solady/src/tokens/ERC721.sol";
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

contract TestERC721ShipyardRedeemable is BaseRedeemablesTest {
    using OfferItemLib for OfferItem;
    using OfferItemLib for OfferItem[];
    using ConsiderationItemLib for ConsiderationItem;
    using ConsiderationItemLib for ConsiderationItem[];

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

    function testBurnInternalToken() public {
        uint256 tokenId = 2;
        redeemToken.mint(address(this), tokenId);

        CampaignRequirements[] memory requirements = new CampaignRequirements[](
            1
        );

        requirements[0] = CampaignRequirements({
            offer: defaultCampaignOffer,
            consideration: defaultCampaignConsideration,
            traitRedemptions: new TraitRedemption[](0)
        });

        CampaignParams memory params = CampaignParams({
            requirements: requirements,
            signer: address(0),
            startTime: uint32(block.timestamp),
            endTime: uint32(block.timestamp + 1000),
            maxCampaignRedemptions: 5,
            manager: address(this)
        });

        redeemToken.createCampaign(params, "");

        {
            OfferItem[] memory offerFromEvent = new OfferItem[](1);
            offerFromEvent[0] = OfferItemLib.fromDefault(DEFAULT_ERC721_CAMPAIGN_OFFER).withItemType(ItemType.ERC721)
                .withIdentifierOrCriteria(1);

            ConsiderationItem[] memory considerationFromEvent = new ConsiderationItem[](1);
            considerationFromEvent[0] = ConsiderationItemLib.fromDefault(DEFAULT_ERC721_CAMPAIGN_CONSIDERATION)
                .withItemType(ItemType.ERC721).withIdentifierOrCriteria(tokenId);

            // campaignId: 1
            // requirementsIndex: 0
            // redemptionHash: bytes32(0)
            bytes memory extraData = abi.encode(1, 0, bytes32(0));

            uint256[] memory considerationTokenIds = Solarray.uint256s(tokenId);
            uint256[] memory traitRedemptionTokenIds;

            vm.expectEmit(true, true, true, true);
            emit Redemption(1, 0, bytes32(0), considerationTokenIds, traitRedemptionTokenIds, address(this));
            redeemToken.redeem(considerationTokenIds, address(this), extraData);

            vm.expectRevert(ERC721.TokenDoesNotExist.selector);
            redeemToken.ownerOf(tokenId);

            assertEq(receiveToken.ownerOf(1), address(this));
        }
    }

    function testRevert721ConsiderationItemInsufficientBalance() public {
        uint256 tokenId = 2;
        uint256 invalidTokenId = tokenId + 1;
        redeemToken.mint(address(this), tokenId);
        redeemToken.mint(dillon.addr, invalidTokenId);

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

        {
            CampaignParams memory params = CampaignParams({
                requirements: requirements,
                signer: address(0),
                startTime: uint32(block.timestamp),
                endTime: uint32(block.timestamp + 1000),
                maxCampaignRedemptions: 5,
                manager: address(this)
            });

            redeemToken.createCampaign(params, "");
        }

        {
            OfferItem[] memory offerFromEvent = new OfferItem[](1);
            offerFromEvent[0] = OfferItem({
                itemType: ItemType.ERC721,
                token: address(receiveToken),
                identifierOrCriteria: tokenId,
                startAmount: 1,
                endAmount: 1
            });
            ConsiderationItem[] memory considerationFromEvent = new ConsiderationItem[](1);
            considerationFromEvent[0] = ConsiderationItem({
                itemType: ItemType.ERC721,
                token: address(redeemToken),
                identifierOrCriteria: tokenId,
                startAmount: 1,
                endAmount: 1,
                recipient: payable(_BURN_ADDRESS)
            });

            assertGt(uint256(consideration[0].itemType), uint256(considerationFromEvent[0].itemType));

            // campaignId: 1
            // requirementsIndex: 0
            // redemptionHash: bytes32(0)
            bytes memory extraData = abi.encode(1, 0, bytes32(0));
            consideration[0].identifierOrCriteria = tokenId;

            uint256[] memory tokenIds = Solarray.uint256s(invalidTokenId);

            vm.expectRevert(
                abi.encodeWithSelector(
                    ConsiderationItemInsufficientBalance.selector,
                    requirements[0].consideration[0].token,
                    0,
                    requirements[0].consideration[0].startAmount
                )
            );
            redeemToken.redeem(tokenIds, address(this), extraData);

            assertEq(redeemToken.ownerOf(tokenId), address(this));

            vm.expectRevert(ERC721.TokenDoesNotExist.selector);
            receiveToken.ownerOf(1);
        }
    }

    function testRevertConsiderationLengthNotMet() public {
        ERC721ShipyardRedeemableOwnerMintable secondRedeemToken = new ERC721ShipyardRedeemableOwnerMintable();

        uint256 tokenId = 2;
        redeemToken.mint(address(this), tokenId);

        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItem({
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: address(receiveToken),
            identifierOrCriteria: 0,
            startAmount: 1,
            endAmount: 1
        });

        ConsiderationItem[] memory consideration = new ConsiderationItem[](2);
        consideration[0] = ConsiderationItem({
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: address(redeemToken),
            identifierOrCriteria: 0,
            startAmount: 1,
            endAmount: 1,
            recipient: payable(_BURN_ADDRESS)
        });
        consideration[1] = ConsiderationItem({
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: address(secondRedeemToken),
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

        {
            CampaignParams memory params = CampaignParams({
                requirements: requirements,
                signer: address(0),
                startTime: uint32(block.timestamp),
                endTime: uint32(block.timestamp + 1000),
                maxCampaignRedemptions: 5,
                manager: address(this)
            });

            redeemToken.createCampaign(params, "");
        }

        {
            OfferItem[] memory offerFromEvent = new OfferItem[](1);
            offerFromEvent[0] = OfferItem({
                itemType: ItemType.ERC721,
                token: address(receiveToken),
                identifierOrCriteria: tokenId,
                startAmount: 1,
                endAmount: 1
            });
            ConsiderationItem[] memory considerationFromEvent = new ConsiderationItem[](1);
            considerationFromEvent[0] = ConsiderationItem({
                itemType: ItemType.ERC721,
                token: address(redeemToken),
                identifierOrCriteria: tokenId,
                startAmount: 1,
                endAmount: 1,
                recipient: payable(_BURN_ADDRESS)
            });

            assertGt(uint256(consideration[0].itemType), uint256(considerationFromEvent[0].itemType));

            // campaignId: 1
            // requirementsIndex: 0
            // redemptionHash: bytes32(0)
            bytes memory extraData = abi.encode(1, 0, bytes32(0));
            consideration[0].identifierOrCriteria = tokenId;

            uint256[] memory tokenIds = Solarray.uint256s(tokenId);

            vm.expectRevert(abi.encodeWithSelector(TokenIdsDontMatchConsiderationLength.selector, 2, 1));

            redeemToken.redeem(tokenIds, address(this), extraData);

            assertEq(redeemToken.ownerOf(tokenId), address(this));

            vm.expectRevert(ERC721.TokenDoesNotExist.selector);
            receiveToken.ownerOf(1);
        }
    }

    function testBurnWithSecondConsiderationItem() public {
        ERC721ShipyardRedeemableOwnerMintable secondRedeemToken = new ERC721ShipyardRedeemableOwnerMintable();
        vm.label(address(secondRedeemToken), "secondRedeemToken");
        secondRedeemToken.setApprovalForAll(address(redeemToken), true);

        uint256 tokenId = 2;
        redeemToken.mint(address(this), tokenId);
        secondRedeemToken.mint(address(this), tokenId);

        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItem({
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: address(receiveToken),
            identifierOrCriteria: 0,
            startAmount: 1,
            endAmount: 1
        });

        ConsiderationItem[] memory consideration = new ConsiderationItem[](2);
        consideration[0] = ConsiderationItem({
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: address(redeemToken),
            identifierOrCriteria: 0,
            startAmount: 1,
            endAmount: 1,
            recipient: payable(_BURN_ADDRESS)
        });
        consideration[1] = ConsiderationItem({
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: address(secondRedeemToken),
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

        {
            CampaignParams memory params = CampaignParams({
                requirements: requirements,
                signer: address(0),
                startTime: uint32(block.timestamp),
                endTime: uint32(block.timestamp + 1000),
                maxCampaignRedemptions: 5,
                manager: address(this)
            });

            redeemToken.createCampaign(params, "");
        }

        {
            OfferItem[] memory offerFromEvent = new OfferItem[](1);
            offerFromEvent[0] = OfferItem({
                itemType: ItemType.ERC721,
                token: address(receiveToken),
                identifierOrCriteria: tokenId,
                startAmount: 1,
                endAmount: 1
            });
            ConsiderationItem[] memory considerationFromEvent = new ConsiderationItem[](1);
            considerationFromEvent[0] = ConsiderationItem({
                itemType: ItemType.ERC721,
                token: address(redeemToken),
                identifierOrCriteria: tokenId,
                startAmount: 1,
                endAmount: 1,
                recipient: payable(_BURN_ADDRESS)
            });

            assertGt(uint256(consideration[0].itemType), uint256(considerationFromEvent[0].itemType));

            // campaignId: 1
            // requirementsIndex: 0
            // redemptionHash: bytes32(0)
            bytes memory extraData = abi.encode(1, 0, bytes32(0));
            consideration[0].identifierOrCriteria = tokenId;

            uint256[] memory tokenIds = Solarray.uint256s(tokenId, tokenId);

            redeemToken.redeem(tokenIds, address(this), extraData);

            vm.expectRevert(ERC721.TokenDoesNotExist.selector);
            redeemToken.ownerOf(tokenId);

            assertEq(secondRedeemToken.ownerOf(tokenId), _BURN_ADDRESS);

            assertEq(receiveToken.ownerOf(1), address(this));
        }
    }

    function testBurnWithSecondRequirementsIndex() public {
        ERC721ShipyardRedeemableOwnerMintable secondRedeemToken = new ERC721ShipyardRedeemableOwnerMintable();
        vm.label(address(secondRedeemToken), "secondRedeemToken");
        secondRedeemToken.setApprovalForAll(address(redeemToken), true);

        uint256 tokenId = 2;
        redeemToken.mint(address(this), tokenId);
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
            token: address(redeemToken),
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

        {
            CampaignParams memory params = CampaignParams({
                requirements: requirements,
                signer: address(0),
                startTime: uint32(block.timestamp),
                endTime: uint32(block.timestamp + 1000),
                maxCampaignRedemptions: 5,
                manager: address(this)
            });

            redeemToken.createCampaign(params, "");
        }

        {
            OfferItem[] memory offerFromEvent = new OfferItem[](1);
            offerFromEvent[0] = OfferItem({
                itemType: ItemType.ERC721,
                token: address(receiveToken),
                identifierOrCriteria: tokenId,
                startAmount: 1,
                endAmount: 1
            });
            ConsiderationItem[] memory considerationFromEvent = new ConsiderationItem[](1);
            considerationFromEvent[0] = ConsiderationItem({
                itemType: ItemType.ERC721,
                token: address(redeemToken),
                identifierOrCriteria: tokenId,
                startAmount: 1,
                endAmount: 1,
                recipient: payable(_BURN_ADDRESS)
            });

            assertGt(uint256(consideration[0].itemType), uint256(considerationFromEvent[0].itemType));

            // campaignId: 1
            // requirementsIndex: 0
            // redemptionHash: bytes32(0)
            bytes memory extraData = abi.encode(1, 1, bytes32(0));
            consideration[0].identifierOrCriteria = tokenId;

            uint256[] memory tokenIds = Solarray.uint256s(tokenId);

            redeemToken.redeem(tokenIds, address(this), extraData);

            assertEq(redeemToken.ownerOf(tokenId), address(this));

            assertEq(secondRedeemToken.ownerOf(tokenId), _BURN_ADDRESS);

            assertEq(receiveToken.ownerOf(1), address(this));
        }
    }

    function testRevertInvalidTxValue() public {
        uint256 tokenId = 2;
        redeemToken.mint(address(this), tokenId);

        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItem({
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: address(receiveToken),
            identifierOrCriteria: 0,
            startAmount: 1,
            endAmount: 1
        });

        ConsiderationItem[] memory consideration = new ConsiderationItem[](2);
        consideration[0] = ConsiderationItem({
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: address(redeemToken),
            identifierOrCriteria: 0,
            startAmount: 1,
            endAmount: 1,
            recipient: payable(_BURN_ADDRESS)
        });
        consideration[1] = ConsiderationItem({
            itemType: ItemType.NATIVE,
            token: address(0),
            identifierOrCriteria: 0,
            startAmount: 0.1 ether,
            endAmount: 0.1 ether,
            recipient: payable(dillon.addr)
        });

        CampaignRequirements[] memory requirements = new CampaignRequirements[](
            1
        );
        requirements[0].offer = offer;
        requirements[0].consideration = consideration;

        {
            CampaignParams memory params = CampaignParams({
                requirements: requirements,
                signer: address(0),
                startTime: uint32(block.timestamp),
                endTime: uint32(block.timestamp + 1000),
                maxCampaignRedemptions: 5,
                manager: address(this)
            });

            redeemToken.createCampaign(params, "");
        }

        {
            OfferItem[] memory offerFromEvent = new OfferItem[](1);
            offerFromEvent[0] = OfferItem({
                itemType: ItemType.ERC721,
                token: address(receiveToken),
                identifierOrCriteria: tokenId,
                startAmount: 1,
                endAmount: 1
            });
            ConsiderationItem[] memory considerationFromEvent = new ConsiderationItem[](1);
            considerationFromEvent[0] = ConsiderationItem({
                itemType: ItemType.ERC721,
                token: address(redeemToken),
                identifierOrCriteria: tokenId,
                startAmount: 1,
                endAmount: 1,
                recipient: payable(_BURN_ADDRESS)
            });

            assertGt(uint256(consideration[0].itemType), uint256(considerationFromEvent[0].itemType));

            // campaignId: 1
            // requirementsIndex: 0
            // redemptionHash: bytes32(0)
            bytes memory extraData = abi.encode(1, 0, bytes32(0));
            consideration[0].identifierOrCriteria = tokenId;

            uint256[] memory considerationTokenIds = Solarray.uint256s(tokenId, 0);
            uint256[] memory traitRedemptionTokenIds;

            vm.expectRevert(abi.encodeWithSelector(InvalidTxValue.selector, 0.05 ether, 0.1 ether));
            redeemToken.redeem{value: 0.05 ether}(considerationTokenIds, address(this), extraData);

            vm.expectRevert(ERC721.TokenDoesNotExist.selector);
            receiveToken.ownerOf(1);

            assertEq(redeemToken.ownerOf(tokenId), address(this));
        }
    }

    function testRevertErc20ConsiderationItemInsufficientBalance() public {
        uint256 tokenId = 2;
        redeemToken.mint(address(this), tokenId);

        TestERC20 redeemErc20 = new TestERC20();
        redeemErc20.mint(address(this), 0.05 ether);
        redeemErc20.approve(address(redeemToken), 1 ether);

        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItem({
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: address(receiveToken),
            identifierOrCriteria: 0,
            startAmount: 1,
            endAmount: 1
        });

        ConsiderationItem[] memory consideration = new ConsiderationItem[](2);
        consideration[0] = ConsiderationItem({
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: address(redeemToken),
            identifierOrCriteria: 0,
            startAmount: 1,
            endAmount: 1,
            recipient: payable(_BURN_ADDRESS)
        });
        consideration[1] = ConsiderationItem({
            itemType: ItemType.ERC20,
            token: address(redeemErc20),
            identifierOrCriteria: 0,
            startAmount: 0.1 ether,
            endAmount: 0.1 ether,
            recipient: payable(dillon.addr)
        });

        CampaignRequirements[] memory requirements = new CampaignRequirements[](
            1
        );
        requirements[0].offer = offer;
        requirements[0].consideration = consideration;

        {
            CampaignParams memory params = CampaignParams({
                requirements: requirements,
                signer: address(0),
                startTime: uint32(block.timestamp),
                endTime: uint32(block.timestamp + 1000),
                maxCampaignRedemptions: 5,
                manager: address(this)
            });

            redeemToken.createCampaign(params, "");
        }

        {
            OfferItem[] memory offerFromEvent = new OfferItem[](1);
            offerFromEvent[0] = OfferItem({
                itemType: ItemType.ERC721,
                token: address(receiveToken),
                identifierOrCriteria: tokenId,
                startAmount: 1,
                endAmount: 1
            });
            ConsiderationItem[] memory considerationFromEvent = new ConsiderationItem[](1);
            considerationFromEvent[0] = ConsiderationItem({
                itemType: ItemType.ERC721,
                token: address(redeemToken),
                identifierOrCriteria: tokenId,
                startAmount: 1,
                endAmount: 1,
                recipient: payable(_BURN_ADDRESS)
            });

            assertGt(uint256(consideration[0].itemType), uint256(considerationFromEvent[0].itemType));

            // campaignId: 1
            // requirementsIndex: 0
            // redemptionHash: bytes32(0)
            bytes memory extraData = abi.encode(1, 0, bytes32(0));
            consideration[0].identifierOrCriteria = tokenId;

            uint256[] memory considerationTokenIds = Solarray.uint256s(tokenId, 0);
            uint256[] memory traitRedemptionTokenIds;

            vm.expectRevert(
                abi.encodeWithSelector(
                    ConsiderationItemInsufficientBalance.selector, address(redeemErc20), 0.05 ether, 0.1 ether
                )
            );
            redeemToken.redeem(considerationTokenIds, address(this), extraData);

            vm.expectRevert(ERC721.TokenDoesNotExist.selector);
            receiveToken.ownerOf(1);

            assertEq(redeemToken.ownerOf(tokenId), address(this));
        }
    }

    function testRevertErc721InvalidConsiderationTokenIdSupplied() public {
        uint256 tokenId = 2;
        uint256 considerationTokenId = 1;
        redeemToken.mint(address(this), tokenId);
        redeemToken.mint(address(this), considerationTokenId);

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
            itemType: ItemType.ERC721,
            token: address(redeemToken),
            identifierOrCriteria: considerationTokenId,
            startAmount: 1,
            endAmount: 1,
            recipient: payable(_BURN_ADDRESS)
        });

        CampaignRequirements[] memory requirements = new CampaignRequirements[](
            1
        );
        requirements[0].offer = offer;
        requirements[0].consideration = consideration;

        {
            CampaignParams memory params = CampaignParams({
                requirements: requirements,
                signer: address(0),
                startTime: uint32(block.timestamp),
                endTime: uint32(block.timestamp + 1000),
                maxCampaignRedemptions: 5,
                manager: address(this)
            });

            redeemToken.createCampaign(params, "");
        }

        {
            OfferItem[] memory offerFromEvent = new OfferItem[](1);
            offerFromEvent[0] = OfferItem({
                itemType: ItemType.ERC721,
                token: address(receiveToken),
                identifierOrCriteria: tokenId,
                startAmount: 1,
                endAmount: 1
            });
            ConsiderationItem[] memory considerationFromEvent = new ConsiderationItem[](1);
            considerationFromEvent[0] = ConsiderationItem({
                itemType: ItemType.ERC721,
                token: address(redeemToken),
                identifierOrCriteria: tokenId,
                startAmount: 1,
                endAmount: 1,
                recipient: payable(_BURN_ADDRESS)
            });

            // campaignId: 1
            // requirementsIndex: 0
            // redemptionHash: bytes32(0)
            bytes memory extraData = abi.encode(1, 0, bytes32(0));

            uint256[] memory considerationTokenIds = Solarray.uint256s(tokenId);

            vm.expectRevert(
                abi.encodeWithSelector(
                    InvalidConsiderationTokenIdSupplied.selector, address(redeemToken), tokenId, considerationTokenId
                )
            );
            redeemToken.redeem(considerationTokenIds, address(this), extraData);

            vm.expectRevert(ERC721.TokenDoesNotExist.selector);
            receiveToken.ownerOf(1);

            assertEq(redeemToken.ownerOf(tokenId), address(this));
            assertEq(redeemToken.ownerOf(considerationTokenId), address(this));
        }
    }

    function testRevertErc1155InvalidConsiderationTokenIdSupplied() public {
        TestERC1155 redeemErc1155 = new TestERC1155();
        uint256 tokenId = 2;
        uint256 considerationTokenId = 1;
        redeemErc1155.mint(address(this), tokenId, 1 ether);
        redeemErc1155.mint(address(this), considerationTokenId, 1 ether);

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
            itemType: ItemType.ERC1155,
            token: address(redeemErc1155),
            identifierOrCriteria: considerationTokenId,
            startAmount: 1,
            endAmount: 1,
            recipient: payable(_BURN_ADDRESS)
        });

        CampaignRequirements[] memory requirements = new CampaignRequirements[](
            1
        );
        requirements[0].offer = offer;
        requirements[0].consideration = consideration;

        {
            CampaignParams memory params = CampaignParams({
                requirements: requirements,
                signer: address(0),
                startTime: uint32(block.timestamp),
                endTime: uint32(block.timestamp + 1000),
                maxCampaignRedemptions: 5,
                manager: address(this)
            });

            redeemToken.createCampaign(params, "");
        }

        {
            OfferItem[] memory offerFromEvent = new OfferItem[](1);
            offerFromEvent[0] = OfferItem({
                itemType: ItemType.ERC721,
                token: address(receiveToken),
                identifierOrCriteria: tokenId,
                startAmount: 1,
                endAmount: 1
            });
            ConsiderationItem[] memory considerationFromEvent = new ConsiderationItem[](1);
            considerationFromEvent[0] = ConsiderationItem({
                itemType: ItemType.ERC721,
                token: address(redeemToken),
                identifierOrCriteria: tokenId,
                startAmount: 1,
                endAmount: 1,
                recipient: payable(_BURN_ADDRESS)
            });

            assertGt(uint256(consideration[0].itemType), uint256(considerationFromEvent[0].itemType));

            // campaignId: 1
            // requirementsIndex: 0
            // redemptionHash: bytes32(0)
            bytes memory extraData = abi.encode(1, 0, bytes32(0));
            consideration[0].identifierOrCriteria = tokenId;

            uint256[] memory considerationTokenIds = Solarray.uint256s(tokenId);
            uint256[] memory traitRedemptionTokenIds;

            vm.expectRevert(
                abi.encodeWithSelector(
                    InvalidConsiderationTokenIdSupplied.selector, address(redeemErc1155), tokenId, considerationTokenId
                )
            );
            redeemToken.redeem(considerationTokenIds, address(this), extraData);

            vm.expectRevert(ERC721.TokenDoesNotExist.selector);
            receiveToken.ownerOf(1);

            assertEq(redeemErc1155.balanceOf(address(this), tokenId), 1 ether);
            assertEq(redeemErc1155.balanceOf(address(this), considerationTokenId), 1 ether);
        }
    }

    // ERC721: specific id ONLY
    // ERC721_WITH_CRITERIA id=0: wildcard
    // ERC721_WITH_CRITERIA id=!0: revert
    // ^ add this validation to create/update campaign
    // ERC1155: specific ID ONLY
    // ERC1155_WITH_CRITERIA id=0: wildcard
    // ERC1155_WITH_CRITERIA id=!0: revert
    // ERC20
    // NATIVE

    // RedeemablesTestHelper.sol, with CampaignParams in storage
}

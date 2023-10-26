// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {BaseRedeemablesTest} from "./utils/BaseRedeemablesTest.sol";
import {Solarray} from "solarray/Solarray.sol";
import {ERC721} from "solady/src/tokens/ERC721.sol";
import {IERC7498} from "../src/interfaces/IERC7498.sol";
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

contract ERC7498_Revert is BaseRedeemablesTest {
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

    function testRevert721ConsiderationItemInsufficientBalance() public {
        ERC721ShipyardRedeemableOwnerMintable(erc7498Tokens[0]).mint(address(this), tokenId);

        uint256 invalidTokenId = tokenId + 1;
        ERC721ShipyardRedeemableOwnerMintable(erc7498Tokens[0]).mint(dillon.addr, invalidTokenId);

        CampaignRequirements[] memory requirements = new CampaignRequirements[](
            1
        );

        requirements[0] = CampaignRequirements({
            offer: defaultCampaignOffer,
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
        uint256[] memory tokenIds = Solarray.uint256s(invalidTokenId);

        vm.expectRevert(
            abi.encodeWithSelector(
                ConsiderationItemInsufficientBalance.selector,
                requirements[0].consideration[0].token,
                0,
                requirements[0].consideration[0].startAmount
            )
        );
        IERC7498(erc7498Tokens[0]).redeem(tokenIds, address(this), extraData);

        assertEq(ERC721(erc7498Tokens[0]).ownerOf(tokenId), address(this));

        vm.expectRevert(ERC721.TokenDoesNotExist.selector);
        receiveToken721.ownerOf(1);
    }

    function testRevertConsiderationLengthNotMet() public {
        ERC721ShipyardRedeemableOwnerMintable(erc7498Tokens[0]).mint(address(this), tokenId);

        ERC721ShipyardRedeemableOwnerMintable secondRedeemToken = new ERC721ShipyardRedeemableOwnerMintable(
                "",
                ""
            );

        ConsiderationItem[] memory consideration = new ConsiderationItem[](2);
        consideration[0] = ConsiderationItem({
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: address(erc7498Tokens[0]),
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
        requirements[0].offer = defaultCampaignOffer;
        requirements[0].consideration = consideration;

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
        consideration[0].identifierOrCriteria = tokenId;

        uint256[] memory tokenIds = Solarray.uint256s(tokenId);

        vm.expectRevert(abi.encodeWithSelector(TokenIdsDontMatchConsiderationLength.selector, 2, 1));

        IERC7498(erc7498Tokens[0]).redeem(tokenIds, address(this), extraData);

        assertEq(ERC721(erc7498Tokens[0]).ownerOf(tokenId), address(this));

        vm.expectRevert(ERC721.TokenDoesNotExist.selector);
        receiveToken721.ownerOf(1);
    }

    function testRevertInvalidTxValue() public {
        ERC721ShipyardRedeemableOwnerMintable(erc7498Tokens[0]).mint(address(this), tokenId);

        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItem({
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: address(receiveToken721),
            identifierOrCriteria: 0,
            startAmount: 1,
            endAmount: 1
        });

        ConsiderationItem[] memory consideration = new ConsiderationItem[](2);
        consideration[0] = ConsiderationItem({
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: address(erc7498Tokens[0]),
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
        consideration[0].identifierOrCriteria = tokenId;

        uint256[] memory considerationTokenIds = Solarray.uint256s(tokenId, 0);
        uint256[] memory traitRedemptionTokenIds;

        vm.expectRevert(abi.encodeWithSelector(InvalidTxValue.selector, 0.05 ether, 0.1 ether));
        IERC7498(erc7498Tokens[0]).redeem{value: 0.05 ether}(considerationTokenIds, address(this), extraData);

        vm.expectRevert(ERC721.TokenDoesNotExist.selector);
        receiveToken721.ownerOf(1);

        assertEq(ERC721(erc7498Tokens[0]).ownerOf(tokenId), address(this));
    }

    function testRevertErc20ConsiderationItemInsufficientBalance() public {
        ERC721ShipyardRedeemableOwnerMintable(erc7498Tokens[0]).mint(address(this), tokenId);

        TestERC20 redeemErc20 = new TestERC20();
        redeemErc20.mint(address(this), 0.05 ether);

        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItem({
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: address(receiveToken721),
            identifierOrCriteria: 0,
            startAmount: 1,
            endAmount: 1
        });

        ConsiderationItem[] memory consideration = new ConsiderationItem[](2);
        consideration[0] = ConsiderationItem({
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: address(erc7498Tokens[0]),
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

            IERC7498(erc7498Tokens[0]).createCampaign(params, "");
        }

        // campaignId: 1
        // requirementsIndex: 0
        // redemptionHash: bytes32(0)
        bytes memory extraData = abi.encode(1, 0, bytes32(0), defaultTraitRedemptionTokenIds, uint256(0), bytes(""));
        consideration[0].identifierOrCriteria = tokenId;

        uint256[] memory considerationTokenIds = Solarray.uint256s(tokenId, 0);

        vm.expectRevert(
            abi.encodeWithSelector(
                ConsiderationItemInsufficientBalance.selector, address(redeemErc20), 0.05 ether, 0.1 ether
            )
        );
        IERC7498(erc7498Tokens[0]).redeem(considerationTokenIds, address(this), extraData);

        vm.expectRevert(ERC721.TokenDoesNotExist.selector);
        receiveToken721.ownerOf(1);

        assertEq(ERC721(erc7498Tokens[0]).ownerOf(tokenId), address(this));
    }

    function testRevertErc721InvalidConsiderationTokenIdSupplied() public {
        uint256 considerationTokenId = 1;
        ERC721ShipyardRedeemableOwnerMintable(erc7498Tokens[0]).mint(address(this), tokenId);
        ERC721ShipyardRedeemableOwnerMintable(erc7498Tokens[0]).mint(address(this), considerationTokenId);

        CampaignRequirements[] memory requirements = new CampaignRequirements[](
            1
        );

        ConsiderationItem[] memory consideration = new ConsiderationItem[](1);
        consideration[0] = defaultCampaignConsideration[0].withIdentifierOrCriteria(considerationTokenId);

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

        uint256[] memory considerationTokenIds = Solarray.uint256s(tokenId);

        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidConsiderationTokenIdSupplied.selector, address(erc7498Tokens[0]), tokenId, considerationTokenId
            )
        );
        IERC7498(erc7498Tokens[0]).redeem(considerationTokenIds, address(this), extraData);

        vm.expectRevert(ERC721.TokenDoesNotExist.selector);
        receiveToken721.ownerOf(1);

        assertEq(ERC721(erc7498Tokens[0]).ownerOf(tokenId), address(this));
        assertEq(ERC721(erc7498Tokens[0]).ownerOf(considerationTokenId), address(this));
    }

    function testRevertErc1155InvalidConsiderationTokenIdSupplied() public {
        uint256 considerationTokenId = 1;
        erc1155s[0].mint(address(this), tokenId, 1 ether);
        erc1155s[0].mint(address(this), considerationTokenId, 1 ether);

        CampaignRequirements[] memory requirements = new CampaignRequirements[](
            1
        );

        ConsiderationItem[] memory consideration = new ConsiderationItem[](1);
        consideration[0] = defaultCampaignConsideration[0].withToken(address(erc1155s[0])).withItemType(
            ItemType.ERC1155
        ).withIdentifierOrCriteria(considerationTokenId);

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

        uint256[] memory considerationTokenIds = Solarray.uint256s(tokenId);

        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidConsiderationTokenIdSupplied.selector, address(erc1155s[0]), tokenId, considerationTokenId
            )
        );
        IERC7498(erc7498Tokens[0]).redeem(considerationTokenIds, address(this), extraData);

        vm.expectRevert(ERC721.TokenDoesNotExist.selector);
        receiveToken721.ownerOf(1);

        assertEq(erc1155s[0].balanceOf(address(this), tokenId), 1 ether);
        assertEq(erc1155s[0].balanceOf(address(this), considerationTokenId), 1 ether);
    }
}

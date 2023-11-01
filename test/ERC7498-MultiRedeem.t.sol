// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {BaseRedeemablesTest} from "./utils/BaseRedeemablesTest.sol";
import {Solarray} from "solarray/Solarray.sol";
import {ERC721} from "solady/src/tokens/ERC721.sol";
import {TestERC20} from "./utils/mocks/TestERC20.sol";
import {TestERC721} from "./utils/mocks/TestERC721.sol";
import {TestERC1155} from "./utils/mocks/TestERC1155.sol";
import {IERC165} from "openzeppelin-contracts/contracts/interfaces/IERC165.sol";
import {IERC721A} from "seadrop/lib/ERC721A/contracts/IERC721A.sol";
import {IERC721} from "openzeppelin-contracts/contracts/interfaces/IERC721.sol";
import {IERC1155} from "openzeppelin-contracts/contracts/interfaces/IERC1155.sol";
import {IERC7498} from "../src/interfaces/IERC7498.sol";
import {OfferItem, ConsiderationItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {ItemType, OrderType, Side} from "seaport-sol/src/SeaportEnums.sol";
import {OfferItemLib} from "seaport-sol/src/lib/OfferItemLib.sol";
import {ConsiderationItemLib} from "seaport-sol/src/lib/ConsiderationItemLib.sol";
import {CampaignParams, CampaignRequirements, TraitRedemption} from "../src/lib/RedeemablesStructs.sol";
import {ERC721RedemptionMintable} from "../src/extensions/ERC721RedemptionMintable.sol";
import {ERC721ShipyardRedeemableOwnerMintable} from "../src/test/ERC721ShipyardRedeemableOwnerMintable.sol";
import {ERC1155ShipyardRedeemableOwnerMintable} from "../src/test/ERC1155ShipyardRedeemableOwnerMintable.sol";
import {ERC1155ShipyardRedeemableMintable} from "../src/extensions/ERC1155ShipyardRedeemableMintable.sol";

contract ERC7498_MultiRedeem is BaseRedeemablesTest {
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

    function testBurnMultiErc721OrErc1155RedeemSingleErc721() public {
        for (uint256 i; i < erc7498Tokens.length; i++) {
            bool isErc7498Token721 = IERC165(address(erc7498Tokens[i])).supportsInterface(type(IERC721).interfaceId);

            bool isErc7498TokenSeaDrop = _isErc7498TokenSeaDrop(address(erc7498Tokens[i]));
            testRedeemable(
                this.burnMultiErc721OrErc1155RedeemSingleErc721,
                RedeemablesContext({
                    erc7498Token: IERC7498(erc7498Tokens[i]),
                    isErc7498Token721: isErc7498Token721,
                    isErc7498TokenSeaDrop: isErc7498TokenSeaDrop
                })
            );
        }
    }

    function burnMultiErc721OrErc1155RedeemSingleErc721(RedeemablesContext memory context) public {
        address secondRedeemTokenAddress;
        if (context.isErc7498Token721) {
            ERC721ShipyardRedeemableOwnerMintable(address(context.erc7498Token)).mint(address(this), tokenId);

            ERC721ShipyardRedeemableOwnerMintable secondRedeemToken721 = new ERC721ShipyardRedeemableOwnerMintable(
                    "",
                    ""
                );
            secondRedeemTokenAddress = address(secondRedeemToken721);
            secondRedeemToken721.mint(address(this), tokenId);

            vm.label(address(secondRedeemToken721), "secondRedeemToken721");
            secondRedeemToken721.setApprovalForAll(address(context.erc7498Token), true);
        } else {
            ERC1155ShipyardRedeemableOwnerMintable(address(context.erc7498Token)).mint(address(this), tokenId, 1);
            ERC1155ShipyardRedeemableOwnerMintable secondRedeemToken1155 = new ERC1155ShipyardRedeemableOwnerMintable(
                    "",
                    ""
                );
            secondRedeemTokenAddress = address(secondRedeemToken1155);
            secondRedeemToken1155.mint(address(this), tokenId, 1);
            secondRedeemToken1155.setApprovalForAll(address(context.erc7498Token), true);
        }

        ERC721RedemptionMintable receiveToken = new ERC721RedemptionMintable(
            "TestRedeemablesReceive721",
            "TEST",
            erc7498Tokens
        );

        ConsiderationItem[] memory consideration = new ConsiderationItem[](2);
        consideration[0] = _getCampaignConsiderationItem(address(context.erc7498Token), context.isErc7498Token721);
        consideration[1] = _getCampaignConsiderationItem(secondRedeemTokenAddress, context.isErc7498Token721);

        CampaignRequirements[] memory requirements = new CampaignRequirements[](
            1
        );
        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = defaultCampaignOffer[0].withToken(address(receiveToken));
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

        IERC7498(context.erc7498Token).createCampaign(params, "");
        // campaignId: 1
        // requirementsIndex: 0
        // redemptionHash: bytes32(0)
        bytes memory extraData = abi.encode(1, 0, bytes32(0), defaultTraitRedemptionTokenIds, uint256(0), bytes(""));
        consideration[0].identifierOrCriteria = tokenId;

        uint256[] memory tokenIds = Solarray.uint256s(tokenId, tokenId);

        IERC7498(context.erc7498Token).redeem(tokenIds, address(this), extraData);

        _checkTokenDoesNotExist(
            address(context.erc7498Token), tokenId, context.isErc7498Token721, context.isErc7498TokenSeaDrop
        );

        _checkTokenSentToBurnAddress(secondRedeemTokenAddress, tokenId, context.isErc7498Token721);

        assertEq(receiveToken.ownerOf(1), address(this));
        assertEq(receiveToken.balanceOf(address(this)), 1);
    }

    function testBurnOneErc721OrErc1155RedeemMultiErc1155() public {
        for (uint256 i; i < erc7498Tokens.length; i++) {
            bool isErc7498Token721 = IERC165(address(erc7498Tokens[i])).supportsInterface(type(IERC721).interfaceId);

            bool isErc7498TokenSeaDrop = _isErc7498TokenSeaDrop(address(erc7498Tokens[i]));
            testRedeemable(
                this.burnOneErc721OrErc1155RedeemMultiErc1155,
                RedeemablesContext({
                    erc7498Token: IERC7498(erc7498Tokens[i]),
                    isErc7498Token721: isErc7498Token721,
                    isErc7498TokenSeaDrop: isErc7498TokenSeaDrop
                })
            );
        }
    }

    function burnOneErc721OrErc1155RedeemMultiErc1155(RedeemablesContext memory context) public {
        if (context.isErc7498Token721) {
            ERC721ShipyardRedeemableOwnerMintable(address(context.erc7498Token)).mint(address(this), tokenId);
        } else {
            ERC1155ShipyardRedeemableOwnerMintable(address(context.erc7498Token)).mint(address(this), tokenId, 1);
        }

        ERC1155ShipyardRedeemableMintable receiveToken = new ERC1155ShipyardRedeemableMintable(
                "TestRedeemablesReceive1155SequentialIds",
                "TEST"
            );
        ERC721(address(context.erc7498Token)).setApprovalForAll(address(receiveToken), true);

        OfferItem[] memory offer = new OfferItem[](3);
        offer[0] = OfferItem({
            itemType: ItemType.ERC1155_WITH_CRITERIA,
            token: address(receiveToken),
            identifierOrCriteria: 0,
            startAmount: 1,
            endAmount: 1
        });
        offer[1] = OfferItem({
            itemType: ItemType.ERC1155_WITH_CRITERIA,
            token: address(receiveToken),
            identifierOrCriteria: 0,
            startAmount: 1,
            endAmount: 1
        });
        offer[2] = OfferItem({
            itemType: ItemType.ERC1155_WITH_CRITERIA,
            token: address(receiveToken),
            identifierOrCriteria: 0,
            startAmount: 1,
            endAmount: 1
        });

        ConsiderationItem[] memory consideration = new ConsiderationItem[](1);
        consideration[0] = _getCampaignConsiderationItem(address(context.erc7498Token), context.isErc7498Token721);

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

        IERC7498(receiveToken).createCampaign(params, "");
        // campaignId: 1
        // requirementsIndex: 0
        // redemptionHash: bytes32(0)
        bytes memory extraData = abi.encode(1, 0, bytes32(0), defaultTraitRedemptionTokenIds, uint256(0), bytes(""));
        consideration[0].identifierOrCriteria = tokenId;

        uint256[] memory tokenIds = Solarray.uint256s(tokenId);

        IERC7498(receiveToken).redeem(tokenIds, address(this), extraData);

        _checkTokenDoesNotExist(
            address(context.erc7498Token), tokenId, context.isErc7498Token721, context.isErc7498TokenSeaDrop
        );

        assertEq(receiveToken.balanceOf(address(this), 1), 1);
        assertEq(receiveToken.balanceOf(address(this), 2), 1);
        assertEq(receiveToken.balanceOf(address(this), 3), 1);
    }
}

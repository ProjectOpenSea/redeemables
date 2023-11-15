// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {BaseRedeemablesTest} from "./utils/BaseRedeemablesTest.sol";
import {Solarray} from "solarray/Solarray.sol";
import {ERC721} from "solady/src/tokens/ERC721.sol";
import {OfferItem, ConsiderationItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {ItemType, OrderType, Side} from "seaport-sol/src/SeaportEnums.sol";
import {OfferItemLib} from "seaport-sol/src/lib/OfferItemLib.sol";
import {ConsiderationItemLib} from "seaport-sol/src/lib/ConsiderationItemLib.sol";
import {IERC7498} from "../src/interfaces/IERC7498.sol";
import {Campaign, CampaignParams, CampaignRequirements} from "../src/lib/RedeemablesStructs.sol";
import {ERC721ShipyardRedeemableMintable} from "../src/extensions/ERC721ShipyardRedeemableMintable.sol";
import {ERC1155ShipyardRedeemableMintable} from "../src/extensions/ERC1155ShipyardRedeemableMintable.sol";
import {ERC721ShipyardRedeemableOwnerMintable} from "../src/test/ERC721ShipyardRedeemableOwnerMintable.sol";
import {ERC1155ShipyardRedeemableOwnerMintable} from "../src/test/ERC1155ShipyardRedeemableOwnerMintable.sol";

contract ERC7498_MultiRedeem is BaseRedeemablesTest {
    using OfferItemLib for OfferItem;
    using OfferItemLib for OfferItem[];
    using ConsiderationItemLib for ConsiderationItem;
    using ConsiderationItemLib for ConsiderationItem[];

    uint256 tokenId = 2;

    function testBurnMultiErc721OrErc1155RedeemSingleErc721() public {
        for (uint256 i; i < erc7498Tokens.length; i++) {
            testRedeemable(
                this.burnMultiErc721OrErc1155RedeemSingleErc721,
                RedeemablesContext({erc7498Token: IERC7498(erc7498Tokens[i])})
            );
        }
    }

    function burnMultiErc721OrErc1155RedeemSingleErc721(RedeemablesContext memory context) public {
        address secondRedeemTokenAddress;
        _mintToken(address(context.erc7498Token), tokenId);
        if (_isERC721(address(context.erc7498Token))) {
            ERC721ShipyardRedeemableOwnerMintable secondRedeemToken721 = new ERC721ShipyardRedeemableOwnerMintable(
                    "",
                    ""
                );
            secondRedeemTokenAddress = address(secondRedeemToken721);
            vm.label(secondRedeemTokenAddress, "secondRedeemToken721");
            secondRedeemToken721.setApprovalForAll(address(context.erc7498Token), true);
        } else {
            ERC1155ShipyardRedeemableOwnerMintable secondRedeemToken1155 = new ERC1155ShipyardRedeemableOwnerMintable(
                    "",
                    ""
                );
            secondRedeemTokenAddress = address(secondRedeemToken1155);
            vm.label(secondRedeemTokenAddress, "secondRedeemToken1155");
            secondRedeemToken1155.setApprovalForAll(address(context.erc7498Token), true);
        }
        _mintToken(secondRedeemTokenAddress, tokenId);

        ERC721ShipyardRedeemableMintable receiveToken = new ERC721ShipyardRedeemableMintable(
            "",
            ""
        );
        receiveToken.setRedeemablesContracts(erc7498Tokens);
        ConsiderationItem[] memory consideration = new ConsiderationItem[](2);
        consideration[0] = _getCampaignConsiderationItem(address(context.erc7498Token));
        consideration[1] = _getCampaignConsiderationItem(secondRedeemTokenAddress);
        CampaignRequirements[] memory requirements = new CampaignRequirements[](
            1
        );
        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = defaultCampaignOffer[0].withToken(address(receiveToken));
        requirements[0].offer = offer;
        requirements[0].consideration = consideration;
        CampaignParams memory params = CampaignParams({
            startTime: uint32(block.timestamp),
            endTime: uint32(block.timestamp + 1000),
            maxCampaignRedemptions: 5,
            manager: address(this),
            signer: address(0)
        });
        Campaign memory campaign = Campaign({params: params, requirements: requirements});
        context.erc7498Token.createCampaign(campaign, "");
        bytes memory extraData = abi.encode(
            1, // campaignId
            0, // requirementsIndex
            bytes32(0), // redemptionHash
            defaultTraitRedemptionTokenIds,
            uint256(0), // salt
            bytes("") // signature
        );
        consideration[0].identifierOrCriteria = tokenId;
        uint256[] memory tokenIds = Solarray.uint256s(tokenId, tokenId);
        context.erc7498Token.redeem(tokenIds, address(this), extraData);

        _checkTokenDoesNotExist(address(context.erc7498Token), tokenId);
        _checkTokenSentToBurnAddress(secondRedeemTokenAddress, tokenId);
        assertEq(receiveToken.ownerOf(1), address(this));
        assertEq(receiveToken.balanceOf(address(this)), 1);
    }

    function testBurnOneErc721OrErc1155RedeemMultiErc1155() public {
        for (uint256 i; i < erc7498Tokens.length; i++) {
            testRedeemable(
                this.burnOneErc721OrErc1155RedeemMultiErc1155,
                RedeemablesContext({erc7498Token: IERC7498(erc7498Tokens[i])})
            );
        }
    }

    function burnOneErc721OrErc1155RedeemMultiErc1155(RedeemablesContext memory context) public {
        _mintToken(address(context.erc7498Token), tokenId);
        ERC1155ShipyardRedeemableMintable receiveToken = new ERC1155ShipyardRedeemableMintable(
                "",
                ""
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
        consideration[0] = _getCampaignConsiderationItem(address(context.erc7498Token));
        CampaignRequirements[] memory requirements = new CampaignRequirements[](
            1
        );
        requirements[0].offer = offer;
        requirements[0].consideration = consideration;
        CampaignParams memory params = CampaignParams({
            startTime: uint32(block.timestamp),
            endTime: uint32(block.timestamp + 1000),
            maxCampaignRedemptions: 5,
            manager: address(this),
            signer: address(0)
        });
        Campaign memory campaign = Campaign({params: params, requirements: requirements});
        IERC7498(receiveToken).createCampaign(campaign, "");

        bytes memory extraData = abi.encode(
            1, // campaignId
            0, // requirementsIndex
            bytes32(0), // redemptionHash
            defaultTraitRedemptionTokenIds,
            uint256(0), // salt
            bytes("") // signature
        );
        consideration[0].identifierOrCriteria = tokenId;
        uint256[] memory tokenIds = Solarray.uint256s(tokenId);
        IERC7498(receiveToken).redeem(tokenIds, address(this), extraData);

        _checkTokenDoesNotExist(address(context.erc7498Token), tokenId);
        assertEq(receiveToken.balanceOf(address(this), 1), 1);
        assertEq(receiveToken.balanceOf(address(this), 2), 1);
        assertEq(receiveToken.balanceOf(address(this), 3), 1);
    }
}

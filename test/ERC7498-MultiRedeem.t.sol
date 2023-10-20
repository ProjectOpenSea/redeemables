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
            testRedeemable(
                this.burnMultiErc721OrErc1155RedeemSingleErc721,
                RedeemablesContext({erc7498Token: IERC7498(erc7498Tokens[i])})
            );
        }
    }

    function burnMultiErc721OrErc1155RedeemSingleErc721(RedeemablesContext memory context) public {
        bool isErc7498Token721 = _isErc7498Token721(address(context.erc7498Token));

        bool isErc7498TokenSeaDrop = _isErc7498TokenSeaDrop(address(context.erc7498Token));

        address secondRedeemTokenAddress;
        if (isErc7498Token721) {
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

        ConsiderationItem[] memory consideration = new ConsiderationItem[](2);
        consideration[0] = _getCampaignConsiderationItem(address(context.erc7498Token), isErc7498Token721);
        consideration[1] = _getCampaignConsiderationItem(secondRedeemTokenAddress, isErc7498Token721);

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

        IERC7498(context.erc7498Token).createCampaign(params, "");
        // campaignId: 1
        // requirementsIndex: 0
        // redemptionHash: bytes32(0)
        bytes memory extraData = abi.encode(1, 0, bytes32(0));
        consideration[0].identifierOrCriteria = tokenId;

        uint256[] memory tokenIds = Solarray.uint256s(tokenId, tokenId);

        IERC7498(context.erc7498Token).redeem(tokenIds, address(this), extraData);

        _checkTokenDoesNotExist(address(context.erc7498Token), tokenId, isErc7498Token721, isErc7498TokenSeaDrop);

        _checkTokenSentToBurnAddress(secondRedeemTokenAddress, tokenId, isErc7498Token721);

        assertEq(receiveToken721.ownerOf(1), address(this));
    }
}

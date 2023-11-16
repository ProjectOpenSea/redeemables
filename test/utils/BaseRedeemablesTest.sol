// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Solarray} from "solarray/Solarray.sol";
import {ERC721} from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {ERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {IERC165} from "openzeppelin-contracts/contracts/interfaces/IERC165.sol";
import {IERC721A} from "seadrop/lib/ERC721A/contracts/IERC721A.sol";
import {IERC721} from "openzeppelin-contracts/contracts/interfaces/IERC721.sol";
import {IERC1155} from "openzeppelin-contracts/contracts/interfaces/IERC1155.sol";
import {IERC721SeaDrop} from "seadrop/src/interfaces/IERC721SeaDrop.sol";
import {IERC1155SeaDrop} from "seadrop/src/interfaces/IERC1155SeaDrop.sol";
import {BaseOrderTest} from "./BaseOrderTest.sol";
import {IERC7498} from "../../src/interfaces/IERC7498.sol";
import {TestERC20} from "../utils/mocks/TestERC20.sol";
import {TestERC721} from "../utils/mocks/TestERC721.sol";
import {TestERC1155} from "../utils/mocks/TestERC1155.sol";
import {OfferItemLib, ConsiderationItemLib} from "seaport-sol/src/SeaportSol.sol";
import {OfferItem, ConsiderationItem} from "seaport-sol/src/SeaportStructs.sol";
import {ItemType} from "seaport-sol/src/SeaportEnums.sol";
import {ERC721ShipyardRedeemableMintable} from "../../src/extensions/ERC721ShipyardRedeemableMintable.sol";
import {ERC1155ShipyardRedeemableMintable} from "../../src/extensions/ERC1155ShipyardRedeemableMintable.sol";
import {ERC721SeaDropRedeemableOwnerMintable} from "../../src/test/ERC721SeaDropRedeemableOwnerMintable.sol";
import {ERC721ShipyardRedeemableOwnerMintable} from "../../src/test/ERC721ShipyardRedeemableOwnerMintable.sol";
import {ERC1155ShipyardRedeemableOwnerMintable} from "../../src/test/ERC1155ShipyardRedeemableOwnerMintable.sol";
import {ERC1155SeaDropRedeemableOwnerMintable} from "../../src/test/ERC1155SeaDropRedeemableOwnerMintable.sol";
import {ERC721ShipyardRedeemableOwnerMintableWithoutInternalBurn} from
    "../../src/test/ERC721ShipyardRedeemableOwnerMintableWithoutInternalBurn.sol";
import {RedeemablesErrors} from "../../src/lib/RedeemablesErrors.sol";
import {CampaignParams, CampaignRequirements, TraitRedemption} from "../../src/lib/RedeemablesStructs.sol";
import {BURN_ADDRESS} from "../../src/lib/RedeemablesConstants.sol";

contract BaseRedeemablesTest is RedeemablesErrors, BaseOrderTest {
    using OfferItemLib for OfferItem;
    using OfferItemLib for OfferItem[];
    using ConsiderationItemLib for ConsiderationItem;
    using ConsiderationItemLib for ConsiderationItem[];

    struct RedeemablesContext {
        IERC7498 erc7498Token;
    }

    event Redemption(
        uint256 indexed campaignId,
        uint256 requirementsIndex,
        bytes32 redemptionHash,
        uint256[] considerationTokenIds,
        uint256[] traitRedemptionTokenIds,
        address redeemedBy
    );

    address[] erc7498Tokens;
    ERC721ShipyardRedeemableOwnerMintable erc721ShipyardRedeemable;
    ERC721SeaDropRedeemableOwnerMintable erc721SeaDropRedeemable;
    ERC1155ShipyardRedeemableOwnerMintable erc1155ShipyardRedeemable;
    ERC1155SeaDropRedeemableOwnerMintable erc1155SeaDropRedeemable;
    ERC721ShipyardRedeemableOwnerMintableWithoutInternalBurn erc721ShipyardRedeemableWithoutInternalBurn;

    address[] receiveTokens;
    ERC721ShipyardRedeemableMintable receiveToken721;
    ERC1155ShipyardRedeemableMintable receiveToken1155;

    OfferItem[] defaultCampaignOffer;
    ConsiderationItem[] defaultCampaignConsideration;
    TraitRedemption[] defaultTraitRedemptions;
    uint256[] defaultTraitRedemptionTokenIds;

    string constant DEFAULT_ERC721_CAMPAIGN_OFFER = "default erc721 campaign offer";
    string constant DEFAULT_ERC721_CAMPAIGN_CONSIDERATION = "default erc721 campaign consideration";

    function setUp() public virtual override {
        super.setUp();

        erc721ShipyardRedeemable = new ERC721ShipyardRedeemableOwnerMintable(
            "",
            ""
        );
        erc721SeaDropRedeemable = new ERC721SeaDropRedeemableOwnerMintable(
            address(1),
            address(1),
            "",
            ""
        );
        erc1155ShipyardRedeemable = new ERC1155ShipyardRedeemableOwnerMintable(
            "",
            ""
        );
        erc1155SeaDropRedeemable = new ERC1155SeaDropRedeemableOwnerMintable(
            address(1),
            address(1),
            "",
            ""
        );
        erc721ShipyardRedeemableWithoutInternalBurn = new ERC721ShipyardRedeemableOwnerMintableWithoutInternalBurn(
            "",
            ""
        );
        // Not using internal burn needs approval for the contract itself to transfer tokens on users' behalf.
        erc721ShipyardRedeemableWithoutInternalBurn.setApprovalForAll(
            address(erc721ShipyardRedeemableWithoutInternalBurn), true
        );

        erc721SeaDropRedeemable.setMaxSupply(10);
        erc1155SeaDropRedeemable.setMaxSupply(1, 10);
        erc1155SeaDropRedeemable.setMaxSupply(2, 10);
        erc1155SeaDropRedeemable.setMaxSupply(3, 10);

        erc7498Tokens = new address[](5);
        erc7498Tokens[0] = address(erc721ShipyardRedeemable);
        erc7498Tokens[1] = address(erc721SeaDropRedeemable);
        erc7498Tokens[2] = address(erc1155ShipyardRedeemable);
        erc7498Tokens[3] = address(erc1155SeaDropRedeemable);
        erc7498Tokens[4] = address(erc721ShipyardRedeemableWithoutInternalBurn);
        vm.label(erc7498Tokens[0], "erc721ShipyardRedeemable");
        vm.label(erc7498Tokens[1], "erc721SeaDropRedeemable");
        vm.label(erc7498Tokens[2], "erc1155ShipyardRedeemable");
        vm.label(erc7498Tokens[3], "erc1155SeaDropRedeemable");
        vm.label(erc7498Tokens[4], "erc721ShipyardRedeemableWithoutInternalBurn");

        receiveToken721 = new ERC721ShipyardRedeemableMintable("", "");
        receiveToken1155 = new ERC1155ShipyardRedeemableMintable("", "");
        receiveTokens = new address[](2);
        receiveTokens[0] = address(receiveToken721);
        receiveTokens[1] = address(receiveToken1155);
        vm.label(receiveTokens[0], "erc721ShipyardRedeemableMintable");
        vm.label(receiveTokens[1], "erc1155ShipyardRedeemableMintable");
        for (uint256 i = 0; i < receiveTokens.length; ++i) {
            ERC721ShipyardRedeemableMintable(receiveTokens[i]).setRedeemablesContracts(erc7498Tokens);
            assertEq(ERC721ShipyardRedeemableMintable(receiveTokens[i]).getRedeemablesContracts(), erc7498Tokens);
        }

        _setApprovals(address(this));

        // Save the default campaign offer and consideration
        OfferItemLib.fromDefault(SINGLE_ERC721).withToken(address(receiveToken721)).withItemType(
            ItemType.ERC721_WITH_CRITERIA
        ).saveDefault(DEFAULT_ERC721_CAMPAIGN_OFFER);
        ConsiderationItemLib.fromDefault(SINGLE_ERC721).withToken(address(erc7498Tokens[0])).withRecipient(BURN_ADDRESS)
            .withItemType(ItemType.ERC721_WITH_CRITERIA).saveDefault(DEFAULT_ERC721_CAMPAIGN_CONSIDERATION);
        defaultCampaignOffer.push(OfferItemLib.fromDefault(DEFAULT_ERC721_CAMPAIGN_OFFER));
        defaultCampaignConsideration.push(ConsiderationItemLib.fromDefault(DEFAULT_ERC721_CAMPAIGN_CONSIDERATION));
    }

    function testRedeemable(function(RedeemablesContext memory) external fn, RedeemablesContext memory context)
        internal
    {
        fn(context);
    }

    function _setApprovals(address _owner) internal virtual override {
        vm.startPrank(_owner);
        for (uint256 i = 0; i < erc20s.length; ++i) {
            for (uint256 j = 0; j < erc7498Tokens.length; ++j) {
                erc20s[i].approve(address(erc7498Tokens[j]), type(uint256).max);
            }
        }
        for (uint256 i = 0; i < erc721s.length; ++i) {
            for (uint256 j = 0; j < erc7498Tokens.length; ++j) {
                erc721s[i].setApprovalForAll(address(erc7498Tokens[j]), true);
            }
        }
        for (uint256 i = 0; i < erc1155s.length; ++i) {
            for (uint256 j = 0; j < erc7498Tokens.length; ++j) {
                erc1155s[i].setApprovalForAll(address(erc7498Tokens[j]), true);
            }
        }
        vm.stopPrank();
    }

    function _isSeaDrop(address token) internal view returns (bool isSeaDrop) {
        if (
            IERC165(token).supportsInterface(type(IERC721SeaDrop).interfaceId)
                || IERC165(token).supportsInterface(type(IERC1155SeaDrop).interfaceId)
        ) {
            isSeaDrop = true;
        }
    }

    function _getCampaignConsiderationItem(address token)
        internal
        view
        returns (ConsiderationItem memory considerationItem)
    {
        considerationItem = defaultCampaignConsideration[0].withToken(token).withItemType(
            _isERC721(address(token)) ? ItemType.ERC721_WITH_CRITERIA : ItemType.ERC1155_WITH_CRITERIA
        );
    }

    function _checkTokenDoesNotExist(address token, uint256 tokenId) internal {
        if (_isERC721(token)) {
            try IERC721(address(token)).ownerOf(tokenId) returns (address owner) {
                assertEq(owner, address(BURN_ADDRESS));
            } catch {}
        } else {
            // token is ERC1155
            assertEq(IERC1155(address(token)).balanceOf(address(this), tokenId), 0);
        }
    }

    function _checkTokenSentToBurnAddress(address token, uint256 tokenId) internal {
        if (_isERC721(token)) {
            assertEq(IERC721(address(token)).ownerOf(tokenId), BURN_ADDRESS);
        } else {
            // token is ERC1155
            assertEq(IERC1155(address(token)).balanceOf(address(this), tokenId), 0);
        }
    }

    function _checkTokenIsOwnedBy(address token, uint256 tokenId, address owner) internal {
        if (_isERC721(token)) {
            assertEq(IERC721(address(token)).ownerOf(tokenId), owner);
        } else if (_isERC20(token)) {
            assertGt(IERC20(address(token)).balanceOf(owner), 0);
        } else {
            // token is ERC1155
            assertGt(IERC1155(address(token)).balanceOf(owner, tokenId), 0);
        }
    }

    function _mintToken(address token, uint256 tokenId) internal {
        if (_isERC721(token)) {
            ERC721ShipyardRedeemableOwnerMintable(address(token)).mint(address(this), tokenId);
        } else {
            // token is ERC1155
            ERC1155ShipyardRedeemableOwnerMintable(address(token)).mint(address(this), tokenId, 1);
        }
    }

    function _mintToken(address token, uint256 tokenId, address recipient) internal {
        if (_isERC721(token)) {
            ERC721ShipyardRedeemableOwnerMintable(address(token)).mint(recipient, tokenId);
        } else {
            // token is ERC1155
            ERC1155ShipyardRedeemableOwnerMintable(address(token)).mint(recipient, tokenId, 1);
        }
    }

    function _isERC721(address token) internal view returns (bool isERC721) {
        isERC721 = IERC165(token).supportsInterface(type(IERC721).interfaceId);
    }

    function _isERC20(address token) internal view returns (bool isERC20) {
        isERC20 = IERC165(token).supportsInterface(type(IERC20).interfaceId);
    }
}

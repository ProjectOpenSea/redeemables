// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {BaseRedeemablesTest} from "./utils/BaseRedeemablesTest.sol";
import {IERC165} from "openzeppelin-contracts/contracts/interfaces/IERC165.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {OfferItem, ConsiderationItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {OfferItemLib} from "seaport-sol/src/lib/OfferItemLib.sol";
import {ConsiderationItemLib} from "seaport-sol/src/lib/ConsiderationItemLib.sol";
import {IERC7498} from "../src/interfaces/IERC7498.sol";

contract TestERC7498 is BaseRedeemablesTest {
    using OfferItemLib for OfferItem;
    using OfferItemLib for OfferItem[];
    using ConsiderationItemLib for ConsiderationItem;
    using ConsiderationItemLib for ConsiderationItem[];

    function setUp() public virtual override {
        super.setUp();
    }

    function testSupportsInterfaceId() public {
        for (uint256 i; i < erc7498Tokens.length; i++) {
            bool isErc7498Token721 = IERC165(address(erc7498Tokens[i]))
                .supportsInterface(type(IERC721).interfaceId);
            bool isErc7498TokenSeaDrop = _isErc7498TokenSeaDrop(
                address(erc7498Tokens[i])
            );
            testRedeemable(
                this.supportsInterfaceId,
                RedeemablesContext({
                    erc7498Token: IERC7498(erc7498Tokens[i]),
                    isErc7498Token721: isErc7498Token721,
                    isErc7498TokenSeaDrop: isErc7498TokenSeaDrop
                })
            );
        }
    }

    function supportsInterfaceId(RedeemablesContext memory context) public {
        assertTrue(
            IERC165(address(context.erc7498Token)).supportsInterface(
                type(IERC7498).interfaceId
            )
        );
    }
}

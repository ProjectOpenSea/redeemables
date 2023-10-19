// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {BaseRedeemablesTest} from "./utils/BaseRedeemablesTest.sol";
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
            testRedeemable(this.supportsInterfaceId, RedeemablesContext({erc7498Token: IERC7498(erc7498Tokens[i])}));
        }
    }

    function supportsInterfaceId(RedeemablesContext memory context) public {
        assertTrue(context.erc7498Token.supportsInterface(type(IERC7498).interfaceId));
    }
}

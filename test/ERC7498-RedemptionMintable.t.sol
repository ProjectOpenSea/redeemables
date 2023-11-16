// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {BaseRedeemablesTest} from "./utils/BaseRedeemablesTest.sol";
import {OfferItem, ConsiderationItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {OfferItemLib} from "seaport-sol/src/lib/OfferItemLib.sol";
import {ConsiderationItemLib} from "seaport-sol/src/lib/ConsiderationItemLib.sol";
import {IERC7498} from "../src/interfaces/IERC7498.sol";
import {IRedemptionMintable} from "../src/interfaces/IRedemptionMintable.sol";

contract TestERC7498_RedemptionMintable is BaseRedeemablesTest {
    using OfferItemLib for OfferItem;
    using OfferItemLib for OfferItem[];
    using ConsiderationItemLib for ConsiderationItem;
    using ConsiderationItemLib for ConsiderationItem[];

    function testSupportsInterfaceId() public {
        assertTrue(receiveToken721.supportsInterface(type(IRedemptionMintable).interfaceId));
        assertTrue(receiveToken1155.supportsInterface(type(IRedemptionMintable).interfaceId));

        assertTrue(receiveToken721.supportsInterface(type(IERC7498).interfaceId));
        assertTrue(receiveToken1155.supportsInterface(type(IERC7498).interfaceId));
    }
}

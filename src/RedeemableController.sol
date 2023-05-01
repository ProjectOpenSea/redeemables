// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IERCDynamicTraits} from "./interfaces/IDynamicTraits.sol";

contract RedeemableController {
    mapping(uint256 tokenId => uint256 count) public redeemed;

    function redeem(uint256[] calldata tokenIds) public {
        for (uint256 i = 0; i < tokenIds.length;) {
            _redeem(tokenIds[i]);
            unchecked {
                ++i;
            }
        }
    }

    function _redeem(uint256 tokenId) internal {}
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {SpentItem} from "seaport-types/src/lib/ConsiderationStructs.sol";

interface IERC721RedemptionMintable {
    function mintRedemption(address to, uint256 tokenId) external returns (uint256);
}

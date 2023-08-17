// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ConsiderationItem} from "seaport-types/src/lib/ConsiderationStructs.sol";

interface IERC721RedemptionMintable {
    function mintRedemption(address to, ConsiderationItem[] calldata spent) external returns (uint256 tokenId);
}

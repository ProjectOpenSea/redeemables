// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC1155} from "forge-std/interfaces/IERC1155.sol";
import {RedemptionContextV0} from "../lib/RedeemableStructs.sol";

interface IERC1155RedemptionMintable is IERC1155 {
    function mintWithRedemptionContext(
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        RedemptionContextV0 calldata context
    ) external;
}

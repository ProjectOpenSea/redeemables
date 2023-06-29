// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC721} from "forge-std/interfaces/IERC721.sol";
import {RedemptionContextV0} from "../lib/RedeemableStructs.sol";

interface IERC721RedemptionMintable is IERC721 {
    function mintWithRedemptionContext(address to, uint256 quantity, RedemptionContextV0 calldata context) external;
}

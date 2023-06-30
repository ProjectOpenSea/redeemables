// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {RedemptionContextV0} from "../lib/RedeemableStructs.sol";

interface IERC721RedemptionMintable {
    function mintWithRedemptionContext(address to, RedemptionContextV0 calldata context) external;
}

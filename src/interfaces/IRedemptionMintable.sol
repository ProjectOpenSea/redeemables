// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC165} from "openzeppelin-contracts/contracts/interfaces/IERC165.sol";
import {ConsiderationItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {TraitRedemption} from "../lib/RedeemablesStructs.sol";

interface IRedemptionMintable is IERC165 {
    function mintRedemption(
        uint256 campaignId,
        address recipient,
        ConsiderationItem[] calldata consideration,
        TraitRedemption[] calldata traitRedemptions
    ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {BaseOrderTest} from "./utils/BaseOrderTest.sol";
import {OfferItem, ConsiderationItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {RedeemableContractOffererV0} from "../src/RedeemableContractOffererV0.sol";
import {RedeemableRegistryParamsV0} from "../src/lib/RedeemableStructs.sol";
import {RedeemableErrorsAndEvents} from "../src/lib/RedeemableErrorsAndEvents.sol";

contract TestRedeemableContractOffererV0 is BaseOrderTest, RedeemableErrorsAndEvents {
    RedeemableContractOffererV0 offerer;

    function setUp() public override {
        offerer = new RedeemableContractOffererV0(address(seaport));
    }

    function testSetParams() public {
        RedeemableRegistryParamsV0 memory params = RedeemableRegistryParamsV0({
            offer: new OfferItem[](0),
            consideration: new ConsiderationItem[](1),
            sendTo: address(0),
            requiredSigner: address(0),
            startTime: uint32(block.timestamp),
            endTime: uint32(block.timestamp + 1000),
            maxTotalRedemptions: 5,
            redemptionValuesAreImmutable: false,
            redemptionSettingsAreImmutable: false,
            registeredBy: address(0)
        });

        RedeemableRegistryParamsV0 memory expectedParams = params;
        expectedParams.registeredBy = address(this);

        bytes32 paramsHash = _getRedeemableParamsHash(expectedParams);

        vm.expectEmit(true, true, true, true);
        emit RedeemableParamsUpdated(paramsHash, expectedParams);

        vm.expectEmit(true, true, true, true);
        emit RedeemableURIUpdated(paramsHash, "http://test.com");

        offerer.updateRedeemableParams(bytes32(0), params, "http://test.com");

        RedeemableRegistryParamsV0 memory storedParams = offerer.getRedeemableParams(paramsHash);
        assertEq(storedParams.registeredBy, address(this));
        assertEq(storedParams.sendTo, 0x000000000000000000000000000000000000dEaD);

        string memory storedURI = offerer.redeemableURI(paramsHash);
        assertEq(storedURI, "http://test.com");
    }

    function _getRedeemableParamsHash(RedeemableRegistryParamsV0 memory params) internal pure returns (bytes32) {
        return keccak256(abi.encode(params));
    }
}

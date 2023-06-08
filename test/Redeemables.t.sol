// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Solarray} from "solarray/Solarray.sol";
import {BaseTest} from "./utils/BaseTest.sol";
import {Test721} from "./utils/Test721.sol";
import {DynamicTraitsRegistry} from "../src/DynamicTraitsRegistry.sol";
import {RedeemableController} from "../src/RedeemableController.sol";

contract Example721Test is BaseTest {
    DynamicTraitsRegistry public registry;
    RedeemableController public controller;
    Test721 public token;
    address signer = makeAddr("alice");

    function setUp() public {
        registry = new DynamicTraitsRegistry();
        token = new Test721();
        controller = new RedeemableController(
            address(registry),
            address(token)
        );

        vm.expectEmit(true, true, true, true, address(registry));
        emit OperatorAdded(address(token), address(controller));
        registry.updateAllowedOperator(
            address(token),
            address(controller),
            true
        );
    }

    function testRedeem() public {
        token.mint(address(this), 0);
        bytes memory emptySignature;

        assertEq(controller.isRedeemed(0), false);
        assertEq(registry.getTrait(address(token), 0, _redeemedTraitKey), 0);

        vm.expectEmit(true, true, true, true, address(registry));
        emit TraitUpdated(address(token), 0, _redeemedTraitKey, 0, _REDEEMED);
        controller.redeem(Solarray.uint256s(0), emptySignature, 0);
        assertEq(controller.isRedeemed(0), true);
        assertEq(
            registry.getTrait(address(token), 0, _redeemedTraitKey),
            _REDEEMED
        );

        vm.expectRevert(bytes("already redeemed"));
        controller.redeem(Solarray.uint256s(0), emptySignature, 0);

        token.mint(makeAddr("bob"), 1);
        vm.expectRevert(bytes("not owner"));
        controller.redeem(Solarray.uint256s(1), emptySignature, 0);
    }

    function testRedeemWithSignature() public {
        token.mint(address(this), 1);
        controller.updateSigner(signer);

        assertEq(controller.isRedeemed(1), false);
        assertEq(registry.getTrait(address(token), 1, _redeemedTraitKey), 0);

        uint256[] memory tokenIds = Solarray.uint256s(1);
        uint256 salt = 123;
        bytes memory signature = getSignedRedeem(
            "alice",
            address(controller),
            address(this),
            tokenIds,
            salt
        );

        vm.expectRevert(bytes("invalid signer"));
        controller.redeem(tokenIds, signature, 123456789);

        vm.expectEmit(true, true, true, true, address(registry));
        emit TraitUpdated(address(token), 1, _redeemedTraitKey, 0, _REDEEMED);
        controller.redeem(tokenIds, signature, salt);
        assertEq(controller.isRedeemed(1), true);
        assertEq(
            registry.getTrait(address(token), 1, _redeemedTraitKey),
            _REDEEMED
        );

        vm.expectRevert(bytes("already redeemed"));
        controller.redeem(tokenIds, signature, salt);
    }
}

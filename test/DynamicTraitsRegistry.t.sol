// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { BaseTest } from "./utils/BaseTest.sol";
import { DynamicTraitsRegistry } from "../src/DynamicTraitsRegistry.sol";
import { Test721 } from "./utils/Test721.sol";

contract DynamicTraitsRegistryTest is BaseTest {
    DynamicTraitsRegistry public registry;
    Test721 public token;

    function setUp() public {
        registry = new DynamicTraitsRegistry();
        token = new Test721();
    }

    function testSetTrait() public {
        assertEq(registry.getTrait(address(token), 0, _redeemedTraitKey), 0);

        vm.expectEmit(true, true, true, true, address(registry));
        emit TraitUpdated(address(token), 0, _redeemedTraitKey, 0, _REDEEMED);
        registry.setTrait(address(token), 0, _redeemedTraitKey, _REDEEMED);
        assertEq(
            registry.getTrait(address(token), 0, _redeemedTraitKey), _REDEEMED
        );

        vm.expectRevert(bytes("no change"));
        registry.setTrait(address(token), 0, _redeemedTraitKey, _REDEEMED);

        address greg = makeAddr("greg");
        vm.expectRevert(bytes("not owner or allowed operator"));
        vm.prank(greg);
        registry.setTrait(address(token), 0, _redeemedTraitKey, 0);

        vm.expectEmit(true, true, true, true, address(registry));
        emit OperatorAdded(address(token), greg);
        registry.updateAllowedOperator(address(token), greg, true);

        vm.expectEmit(true, true, true, true, address(registry));
        emit TraitUpdated(address(token), 0, _redeemedTraitKey, _REDEEMED, 0);
        vm.prank(greg);
        registry.setTrait(address(token), 0, _redeemedTraitKey, 0);

        vm.expectEmit(true, true, true, true, address(registry));
        emit OperatorRemoved(address(token), greg);
        registry.updateAllowedOperator(address(token), greg, false);

        vm.expectRevert(bytes("not owner or allowed operator"));
        vm.prank(greg);
        registry.setTrait(address(token), 0, _redeemedTraitKey, 0);
    }

    function testSetTraitBulk() public {
        for (uint256 i = 5; i < 10; i++) {
            assertEq(registry.getTrait(address(token), i, _redeemedTraitKey), 0);
        }

        vm.expectEmit(true, true, true, true, address(registry));
        emit TraitBulkUpdated(address(token), 5, 10, _redeemedTraitKey);
        registry.setTraitBulk(
            address(token), 5, 10, _redeemedTraitKey, _REDEEMED
        );
        for (uint256 i = 5; i < 10; i++) {
            assertEq(
                registry.getTrait(address(token), i, _redeemedTraitKey),
                _REDEEMED
            );
        }

        address fred = makeAddr("fred");
        vm.expectRevert(bytes("not owner or allowed operator"));
        vm.prank(fred);
        registry.setTraitBulk(address(token), 5, 10, _redeemedTraitKey, 0);

        registry.updateAllowedOperator(address(token), fred, true);
        vm.expectEmit(true, true, true, true, address(registry));
        emit TraitBulkUpdated(address(token), 5, 10, _redeemedTraitKey);
        vm.prank(fred);
        registry.setTraitBulk(address(token), 5, 10, _redeemedTraitKey, 0);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Solarray} from "solarray/solarray.sol";
import {BaseTest} from "./utils/BaseTest.sol";
import {Example721} from "../src/Example721.sol";

contract Example721Test is BaseTest {
    Example721 public token;
    address signer = makeAddr("alice");

    function setUp() public {
        token = new Example721();
    }

    function testRedeem() public {
        token.mint(address(this), 0);
        bytes memory emptySignature;

        assertEq(token.isRedeemed(0), false);
        assertEq(token.getTrait(0, _redeemedTraitKey), 0);

        vm.expectEmit(true, true, true, true, address(token));
        emit TraitUpdated(0, _redeemedTraitKey, 0, _REDEEMED);
        token.redeem(Solarray.uint256s(0), emptySignature, 0);
        assertEq(token.isRedeemed(0), true);
        assertEq(token.getTrait(0, _redeemedTraitKey), _REDEEMED);

        vm.expectRevert(bytes("already redeemed"));
        token.redeem(Solarray.uint256s(0), emptySignature, 0);

        token.mint(makeAddr("bob"), 1);
        vm.expectRevert(bytes("not owner"));
        token.redeem(Solarray.uint256s(1), emptySignature, 0);
    }

    function testRedeemWithSignature() public {
        token.mint(address(this), 1);
        token.updateSigner(signer);

        assertEq(token.isRedeemed(1), false);
        assertEq(token.getTrait(1, _redeemedTraitKey), 0);

        uint256[] memory tokenIds = Solarray.uint256s(1);
        uint256 salt = 123;
        bytes memory signature = getSignedRedeem("alice", address(token), address(this), tokenIds, salt);

        vm.expectRevert(bytes("invalid signer"));
        token.redeem(tokenIds, signature, 123456789);

        vm.expectEmit(true, true, true, true, address(token));
        emit TraitUpdated(1, _redeemedTraitKey, 0, _REDEEMED);
        token.redeem(tokenIds, signature, salt);
        assertEq(token.isRedeemed(1), true);
        assertEq(token.getTrait(1, _redeemedTraitKey), _REDEEMED);

        vm.expectRevert(bytes("already redeemed"));
        token.redeem(tokenIds, signature, salt);
    }
}

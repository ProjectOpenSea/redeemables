// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Example721.sol";

contract Example721Test is Test {
    Example721 public token;
    address signer = makeAddr("alice");

    function setUp() public {
        token = new Example721(signer);
    }

    function testRedeem() public {
        token.mint(msg.sender, 0);

        assertEq(token.isRedeemed(0), false);
        token.redeem(0, bytes(0), 0);
        assertEq(token.isRedeemed(0), true);

        vm.expectRevert(bytes("already redeemed"));
        token.redeem(0);
    }
}

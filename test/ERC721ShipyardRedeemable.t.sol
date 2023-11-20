// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {BaseRedeemablesTest} from "./utils/BaseRedeemablesTest.sol";
import {ERC721} from "solady/src/tokens/ERC721.sol";
import {ERC721ShipyardRedeemableOwnerMintable} from "../src/test/ERC721ShipyardRedeemableOwnerMintable.sol";

contract TestERC721ShipyardRedeemable is BaseRedeemablesTest {
    function testBurn() public {
        uint256 tokenId = 1;
        ERC721ShipyardRedeemableOwnerMintable token = new ERC721ShipyardRedeemableOwnerMintable("Test", "TEST");
        address fred = makeAddr("fred");
        _mintToken(address(token), tokenId, fred);

        vm.expectRevert(ERC721.NotOwnerNorApproved.selector);
        token.burn(tokenId);

        vm.expectEmit(true, true, true, true);
        emit Transfer(fred, address(0), tokenId);
        vm.prank(fred);
        token.burn(tokenId);

        vm.expectRevert(ERC721.TokenDoesNotExist.selector);
        token.burn(tokenId + 1);

        _mintToken(address(token), tokenId + 1, fred);
        vm.expectRevert(ERC721.NotOwnerNorApproved.selector);
        token.burn(tokenId + 1);

        vm.prank(fred);
        token.setApprovalForAll(address(this), true);

        vm.expectEmit(true, true, true, true);
        emit Transfer(fred, address(0), tokenId + 1);
        token.burn(tokenId + 1);
    }
}

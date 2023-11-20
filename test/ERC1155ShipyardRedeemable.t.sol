// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Solarray} from "solarray/Solarray.sol";
import {BaseRedeemablesTest} from "./utils/BaseRedeemablesTest.sol";
import {ERC1155} from "solady/src/tokens/ERC1155.sol";
import {ERC1155ShipyardRedeemableOwnerMintable} from "../src/test/ERC1155ShipyardRedeemableOwnerMintable.sol";

contract TestERC1155ShipyardRedeemable is BaseRedeemablesTest {
    event TransferBatch(
        address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] amounts
    );

    function testBurn() public {
        uint256 tokenId = 1;
        ERC1155ShipyardRedeemableOwnerMintable token = new ERC1155ShipyardRedeemableOwnerMintable("Test", "TEST");
        address fred = makeAddr("fred");
        _mintToken(address(token), tokenId, fred);

        vm.expectRevert(ERC1155.InsufficientBalance.selector);
        token.burn(address(this), tokenId, 1);

        vm.expectEmit(true, true, true, true);
        emit TransferSingle(fred, fred, address(0), tokenId, 1);
        vm.prank(fred);
        token.burn(fred, tokenId, 1);

        vm.prank(fred);
        vm.expectRevert(ERC1155.InsufficientBalance.selector);
        token.burn(fred, tokenId + 1, 1);

        _mintToken(address(token), tokenId + 1, fred);
        _mintToken(address(token), tokenId + 2, fred);

        uint256[] memory ids = Solarray.uint256s(tokenId + 1, tokenId + 2);
        uint256[] memory amounts = Solarray.uint256s(1, 1);
        vm.expectRevert(ERC1155.NotOwnerNorApproved.selector);
        token.batchBurn(fred, ids, amounts);

        vm.prank(fred);
        token.setApprovalForAll(address(this), true);

        vm.expectEmit(true, true, true, true);
        emit TransferBatch(address(this), fred, address(0), ids, amounts);
        token.batchBurn(fred, ids, amounts);
    }
}

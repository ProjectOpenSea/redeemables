// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.19;

import {ERC721} from "solady/src/tokens/ERC721.sol";

contract MockERC721DynamicTraits is ERC721 {
    error InvalidCaller();

    // The manager account that can set traits
    address public _manager;

    // The dynamic traits
    mapping(bytes32 traitKey => mapping(uint256 tokenId => bytes32 value)) public traits;

    // Set the manager at construction
    constructor(address manager) {
        _manager = manager;
    }

    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }

    function tokenURI(uint256) public pure override returns (string memory) {
        return "tokenURI";
    }

    function name() public view virtual override returns (string memory) {
        return "TestERC721";
    }

    function symbol() public view virtual override returns (string memory) {
        return "TST721";
    }

    function getTrait(bytes32 traitKey, uint256 tokenId) public view returns (bytes32) {
        return traits[traitKey][tokenId];
    }

    function getTraits(bytes32 traitKey, uint256[] calldata tokenIds) public view returns (bytes32[] memory) {
        bytes32[] memory values = new bytes32[](tokenIds.length);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            values[i] = traits[traitKey][tokenIds[i]];
        }
        return values;
    }

    function setTrait(uint256 tokenId, bytes32 traitKey, bytes32 value) public {
        if (msg.sender != _manager) {
            revert InvalidCaller();
        }
        traits[traitKey][tokenId] = value;
    }
}

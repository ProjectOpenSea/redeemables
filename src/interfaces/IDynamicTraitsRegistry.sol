// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IERCDynamicTraitsRegistry {
    event TraitUpdated(address indexed token, uint256 tokenId, bytes32 traitKey, bytes32 oldValue, bytes32 newValue);
    event TraitBulkUpdated(address indexed token, uint256 fromTokenId, uint256 toTokenId, bytes32 traitKeyPattern);

    function setTrait(uint256 tokenId, bytes32 traitKey, bytes32 value) external;

    function getTrait(address token, uint256 tokenId, bytes32 traitKey) external view returns (bytes32);
}

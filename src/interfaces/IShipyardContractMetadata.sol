// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IShipyardContractMetadata {
    /// @dev Emit an event for token metadata reveals/updates, according to EIP-4906.
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);

    /// @dev Emit an event when the URI for the collection-level metadata is updated.
    event ContractURIUpdated(string uri);

    /// @dev Emit an event when the provenance hash is updated.
    event ProvenanceHashUpdated(bytes32 oldProvenanceHash, bytes32 newProvenanceHash);

    /// @dev Emit an event when the royalties info is updated.
    event RoyaltyInfoUpdated(address receiver, uint256 basisPoints);

    /// @dev Revert with an error when attempting to set the provenance hash after it has already been set.
    error ProvenanceHashCannotBeSetAfterAlreadyBeingSet();

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function baseURI() external view returns (string memory);

    function contractURI() external view returns (string memory);

    function provenanceHash() external view returns (bytes32);

    function setBaseURI(string calldata newURI) external;

    function setContractURI(string calldata newURI) external;

    function setProvenanceHash(bytes32 newProvenanceHash) external;

    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external;
}

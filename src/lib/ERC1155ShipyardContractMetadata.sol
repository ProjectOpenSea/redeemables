// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC1155ConduitPreapproved_Solady} from "shipyard-core/src/tokens/erc1155/ERC1155ConduitPreapproved_Solady.sol";
import {ERC1155} from "solady/src/tokens/ERC1155.sol";
import {ERC2981} from "solady/src/tokens/ERC2981.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";

contract ERC1155ShipyardContractMetadata is ERC1155ConduitPreapproved_Solady, ERC2981, Ownable {
    /// @dev The token name
    string internal _name;

    /// @dev The token symbol
    string internal _symbol;

    /// @dev The base URI.
    string public baseURI;

    /// @dev The contract URI.
    string public contractURI;

    /// @dev The provenance hash for guaranteeing metadata order for random reveals.
    bytes32 public provenanceHash;

    /// @dev Emit an event for token metadata reveals/updates, according to EIP-4906.
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);

    /// @dev Emit an event when the URI for the collection-level metadata is updated.
    event ContractURIUpdated(string uri);

    /// @dev Emit an event when the provenance hash is updated.
    event ProvenanceHashUpdated(bytes32 oldProvenanceHash, bytes32 newProvenanceHash);

    /// @dev Emit an event when the royalties info is updated.
    event RoyaltyInfoUpdated(address receiver, uint256 bps);

    /// @dev Revert with an error when attempting to set the provenance hash after it has already been set.
    error ProvenanceHashCannotBeSetAfterAlreadyBeingSet();

    constructor(string memory name_, string memory symbol_) ERC1155ConduitPreapproved_Solady() {
        // Set the token name and symbol.
        _name = name_;
        _symbol = symbol_;

        // Initialize the owner of the contract.
        _initializeOwner(msg.sender);
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function setBaseURI(string calldata newURI) external onlyOwner {
        baseURI = newURI;

        // Emit an event with the update.
        emit BatchMetadataUpdate(0, type(uint256).max);
    }

    function setContractURI(string calldata newURI) external onlyOwner {
        // Set the new contract URI.
        contractURI = newURI;

        // Emit an event with the update.
        emit ContractURIUpdated(newURI);
    }

    /**
     * @notice Sets the provenance hash and emits an event.
     *
     *         The provenance hash is used for random reveals, which
     *         is a hash of the ordered metadata to show it has not been
     *         modified after mint started.
     *
     *         This function will revert if the provenance hash has already
     *         been set, so be sure to carefully set it only once.
     *
     * @param newProvenanceHash The new provenance hash to set.
     */
    function setProvenanceHash(bytes32 newProvenanceHash) external onlyOwner {
        // Keep track of the old provenance hash for emitting with the event.
        bytes32 oldProvenanceHash = provenanceHash;

        // Revert if the provenance hash has already been set.
        if (oldProvenanceHash != bytes32(0)) {
            revert ProvenanceHashCannotBeSetAfterAlreadyBeingSet();
        }

        // Set the new provenance hash.
        provenanceHash = newProvenanceHash;

        // Emit an event with the update.
        emit ProvenanceHashUpdated(oldProvenanceHash, newProvenanceHash);
    }

    /**
     * @notice Returns the URI for token metadata.
     *
     *         This implementation returns the same URI for *all* token types.
     *         It relies on the token type ID substitution mechanism defined
     *         in the EIP to replace {id} with the token id.
     *
     * @custom:param tokenId The token id to get the URI for.
     */
    function uri(uint256 /* tokenId */ ) public view virtual override returns (string memory) {
        // Return the base URI.
        return baseURI;
    }

    /**
     * @notice Sets the default royalty information.
     *
     * Requirements:
     *
     * - `receiver` cannot be the zero address.
     * - `feeNumerator` cannot be greater than the fee denominator of 10_000 basis points.
     */
    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external onlyOwner {
        // Set the default royalty.
        // ERC2981 implementation ensures feeNumerator <= feeDenominator
        // and receiver != address(0).
        _setDefaultRoyalty(receiver, feeNumerator);

        // Emit an event with the updated params.
        emit RoyaltyInfoUpdated(receiver, feeNumerator);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, ERC2981) returns (bool) {
        return ERC1155.supportsInterface(interfaceId) || ERC2981.supportsInterface(interfaceId);
    }
}

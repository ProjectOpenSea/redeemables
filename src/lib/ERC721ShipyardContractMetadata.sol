// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC721ConduitPreapproved_Solady} from "shipyard-core/src/tokens/erc721/ERC721ConduitPreapproved_Solady.sol";
import {ERC721} from "solady/src/tokens/ERC721.sol";
import {ERC2981} from "solady/src/tokens/ERC2981.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";
import {IShipyardContractMetadata} from "../interfaces/IShipyardContractMetadata.sol";

contract ERC721ShipyardContractMetadata is
    ERC721ConduitPreapproved_Solady,
    IShipyardContractMetadata,
    ERC2981,
    Ownable
{
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

    constructor(string memory name_, string memory symbol_) ERC721ConduitPreapproved_Solady() {
        // Set the token name and symbol.
        _name = name_;
        _symbol = symbol_;

        // Initialize the owner of the contract.
        _initializeOwner(msg.sender);
    }

    /**
     * @notice Returns the name of this token contract.
     */
    function name() public view override(ERC721, IShipyardContractMetadata) returns (string memory) {
        return _name;
    }

    /**
     * @notice Returns the symbol of this token contract.
     */
    function symbol() public view override(ERC721, IShipyardContractMetadata) returns (string memory) {
        return _symbol;
    }

    /**
     * @notice Sets the base URI for the token metadata and emits an event.
     *
     * @param newURI The new base URI to set.
     */
    function setBaseURI(string calldata newURI) external onlyOwner {
        baseURI = newURI;

        // Emit an event with the update.
        emit BatchMetadataUpdate(0, type(uint256).max);
    }

    /**
     * @notice Sets the contract URI for contract metadata.
     *
     * @param newURI The new contract URI.
     */
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
     * @notice Returns the token URI for token metadata.
     *
     * @param tokenId The token id to get the token URI for.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory uri) {
        // Revert if the tokenId doesn't exist.
        if (!_exists(tokenId)) revert TokenDoesNotExist();

        // Put the baseURI on the stack.
        uri = baseURI;

        // Return empty if baseURI is empty.
        if (bytes(uri).length == 0) {
            return "";
        }

        // If the last character of the baseURI is not a slash, then return
        // the baseURI to signal the same metadata for all tokens, such as
        // for a prereveal state.
        if (bytes(uri)[bytes(uri).length - 1] != bytes("/")[0]) {
            return uri;
        }

        // Append the tokenId to the baseURI and return.
        uri = string.concat(uri, _toString(tokenId));
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

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC2981) returns (bool) {
        return ERC721.supportsInterface(interfaceId) || ERC2981.supportsInterface(interfaceId);
    }

    /**
     * @dev Converts a uint256 to its ASCII string decimal representation.
     */
    function _toString(uint256 value) internal pure virtual returns (string memory str) {
        assembly {
            // The maximum value of a uint256 contains 78 digits (1 byte per digit), but
            // we allocate 0xa0 bytes to keep the free memory pointer 32-byte word aligned.
            // We will need 1 word for the trailing zeros padding, 1 word for the length,
            // and 3 words for a maximum of 78 digits. Total: 5 * 0x20 = 0xa0.
            let m := add(mload(0x40), 0xa0)
            // Update the free memory pointer to allocate.
            mstore(0x40, m)
            // Assign the `str` to the end.
            str := sub(m, 0x20)
            // Zeroize the slot after the string.
            mstore(str, 0)

            // Cache the end of the memory to calculate the length later.
            let end := str

            // We write the string from rightmost digit to leftmost digit.
            // The following is essentially a do-while loop that also handles the zero case.
            // prettier-ignore
            for { let temp := value } 1 {} {
                str := sub(str, 1)
                // Write the character to the pointer.
                // The ASCII index of the '0' character is 48.
                mstore8(str, add(48, mod(temp, 10)))
                // Keep dividing `temp` until zero.
                temp := div(temp, 10)
                // prettier-ignore
                if iszero(temp) { break }
            }

            let length := sub(end, str)
            // Move the pointer 32 bytes leftwards to make room for the length.
            str := sub(str, 0x20)
            // Store the length.
            mstore(str, length)
        }
    }
}

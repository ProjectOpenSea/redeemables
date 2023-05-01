// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERCDynamicTraits} from "../../src/interfaces/IDynamicTraits.sol";
import {Solarray} from "solarray/solarray.sol";
import "forge-std/Test.sol";

contract BaseTest is Test, IERCDynamicTraits {
    /// @dev The trait key for "redeemed"
    bytes32 internal constant _redeemedTraitKey =
        bytes32(abi.encodePacked("redeemed"));

    /// @dev Value for if a token is redeemed (1)
    bytes32 internal constant _REDEEMED = bytes32(abi.encode(1));

    /// @notice Internal constants for EIP-712: Typed structured
    ///         data hashing and signing
    bytes32 internal constant _SIGNED_REDEEM_TYPEHASH =
        keccak256(
            "SignedRedeem(address owner,uint256[] tokenIds,uint256 salt)"
        );
    bytes32 internal constant _EIP_712_DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );
    bytes32 internal constant _NAME_HASH = keccak256("Example721");
    bytes32 internal constant _VERSION_HASH = keccak256("1.0");
    uint256 internal immutable _CHAIN_ID = block.chainid;

    function getSignedRedeem(
        string memory signerName,
        address contractAddr,
        address owner,
        uint256[] memory tokenIds,
        uint256 salt
    ) internal returns (bytes memory signature) {
        bytes32 digest = _getDigest(owner, tokenIds, salt, contractAddr);
        (, uint256 pk) = makeAddrAndKey(signerName);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        signature = abi.encodePacked(r, s, v);
    }

    /*
     * @notice Verify an EIP-712 signature by recreating the data structure
     *         that we signed on the client side, and then using that to recover
     *         the address that signed the signature for this data.
     */
    function _getDigest(
        address owner,
        uint256[] memory tokenIds,
        uint256 salt,
        address contractAddr
    ) internal view returns (bytes32 digest) {
        digest = keccak256(
            bytes.concat(
                bytes2(0x1901),
                _domainSeparator(contractAddr),
                keccak256(
                    abi.encode(_SIGNED_REDEEM_TYPEHASH, owner, tokenIds, salt)
                )
            )
        );
    }

    function _domainSeparator(
        address contractAddr
    ) internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    _EIP_712_DOMAIN_TYPEHASH,
                    _NAME_HASH,
                    _VERSION_HASH,
                    block.chainid,
                    contractAddr
                )
            );
    }

    function getTrait(
        uint256,
        bytes32
    ) public view virtual override returns (bytes32) {
        return bytes32(0);
    }
}

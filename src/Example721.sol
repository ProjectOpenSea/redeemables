// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {ERC721} from "solady/tokens/ERC721.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";
import {IERCDynamicTraits} from "./interfaces/IDynamicTraits.sol";

contract Example721 is ERC721, Ownable, IERCDynamicTraits {
    using ECDSA for bytes32;

    mapping(uint256 tokenId => mapping(bytes32 traitKey => bytes32 traitValue)) internal _traits;

    /// @dev The trait key for "redeemed"
    bytes32 internal constant _redeemedTraitKey = bytes32(abi.encodePacked("redeemed"));

    /// @dev Value for if a token is redeemed (1)
    bytes32 internal constant _REDEEMED = bytes32(abi.encode(1));

    /// @dev Signer approval to redeem tokens (e.g. KYC), required when set.
    address internal _redeemSigner;

    /// @notice Internal constants for EIP-712: Typed structured
    ///         data hashing and signing
    bytes32 internal constant _SIGNED_REDEEM_TYPEHASH =
        keccak256("SignedRedeem(address owner,uint256[] tokenIds,uint256 salt)");
    bytes32 internal constant _EIP_712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 internal constant _NAME_HASH = keccak256("Example721");
    bytes32 internal constant _VERSION_HASH = keccak256("1.0");
    uint256 internal immutable _CHAIN_ID = block.chainid;
    bytes32 internal immutable _DOMAIN_SEPARATOR;

    constructor() {
        _initializeOwner(msg.sender);
        _DOMAIN_SEPARATOR = _deriveDomainSeparator();
    }

    function getTrait(uint256 tokenId, bytes32 traitKey) public view virtual override returns (bytes32) {
        return _traits[tokenId][traitKey];
    }

    function isRedeemed(uint256 tokenId) public view returns (bool) {
        return getTrait(tokenId, _redeemedTraitKey) == _REDEEMED;
    }

    function updateSigner(address newSigner) public onlyOwner {
        _redeemSigner = newSigner;
    }

    function redeem(uint256[] calldata tokenIds, bytes calldata signature, uint256 salt) public {
        if (_redeemSigner != address(0)) {
            bytes32 digest = _getDigest(msg.sender, tokenIds, salt);
            address recoveredAddress = digest.recover(signature);
            require(recoveredAddress == _redeemSigner, "invalid signer");
        }

        for (uint256 i = 0; i < tokenIds.length; i++) {
            _redeem(tokenIds[i]);
        }
    }

    function _redeem(uint256 tokenId) internal {
        require(ownerOf(tokenId) == msg.sender, "not owner");
        require(_traits[tokenId][_redeemedTraitKey] == 0, "already redeemed");

        _updateTrait(tokenId, _redeemedTraitKey, _REDEEMED);
    }

    function _updateTrait(uint256 tokenId, bytes32 traitKey, bytes32 newValue) internal {
        bytes32 oldValue = _traits[tokenId][traitKey];
        require(oldValue != newValue, "no change");

        _traits[tokenId][traitKey] = newValue;
        emit TraitUpdated(tokenId, traitKey, oldValue, newValue);
    }

    function name() public view virtual override returns (string memory) {
        return "Example721";
    }

    function symbol() public view virtual override returns (string memory) {
        return "EXAMPLE";
    }

    function mint(address to, uint256 tokenId) public onlyOwner {
        _mint(to, tokenId);
    }

    function tokenURI(uint256 /* tokenId */ ) public view virtual override returns (string memory) {
        return "";
    }

    /*
     * @notice Verify an EIP-712 signature by recreating the data structure
     *         that we signed on the client side, and then using that to recover
     *         the address that signed the signature for this data.
     */
    function _getDigest(address owner, uint256[] calldata tokenIds, uint256 salt)
        internal
        view
        returns (bytes32 digest)
    {
        digest = keccak256(
            bytes.concat(
                bytes2(0x1901),
                _domainSeparator(),
                keccak256(abi.encode(_SIGNED_REDEEM_TYPEHASH, owner, tokenIds, salt))
            )
        );
    }

    /**
     * @dev Internal view function to get the EIP-712 domain separator. If the
     *      chainId matches the chainId set on deployment, the cached domain
     *      separator will be returned; otherwise, it will be derived from
     *      scratch.
     *
     * @return The domain separator.
     */
    function _domainSeparator() internal view returns (bytes32) {
        return block.chainid == _CHAIN_ID ? _DOMAIN_SEPARATOR : _deriveDomainSeparator();
    }

    /**
     * @dev Internal view function to derive the EIP-712 domain separator.
     *
     * @return The derived domain separator.
     */
    function _deriveDomainSeparator() internal view returns (bytes32) {
        return keccak256(abi.encode(_EIP_712_DOMAIN_TYPEHASH, _NAME_HASH, _VERSION_HASH, block.chainid, address(this)));
    }
}

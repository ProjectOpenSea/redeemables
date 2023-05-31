// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { ERC721 } from "solady/tokens/ERC721.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";
import { IERCDynamicTraits } from "./interfaces/IDynamicTraits.sol";
import { SignedRedeem } from "./lib/SignedRedeem.sol";

contract Example721 is ERC721, IERCDynamicTraits, SignedRedeem {
    using ECDSA for bytes32;

    mapping(uint256 tokenId => mapping(bytes32 traitKey => bytes32 traitValue))
        internal _traits;

    /// @dev The trait key for "redeemed"
    bytes32 internal constant _redeemedTraitKey =
        bytes32(abi.encodePacked("redeemed"));

    /// @dev Value for if a token is redeemed (1)
    bytes32 internal constant _REDEEMED = bytes32(abi.encode(1));

    constructor() { }

    function getTrait(uint256 tokenId, bytes32 traitKey)
        public
        view
        virtual
        override
        returns (bytes32)
    {
        return _traits[tokenId][traitKey];
    }

    function isRedeemed(uint256 tokenId) public view returns (bool) {
        return getTrait(tokenId, _redeemedTraitKey) == _REDEEMED;
    }

    function redeem(
        uint256[] calldata tokenIds,
        bytes calldata signature,
        uint256 salt
    ) public {
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

    function _updateTrait(uint256 tokenId, bytes32 traitKey, bytes32 newValue)
        internal
    {
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

    function tokenURI(uint256 /* tokenId */ )
        public
        view
        virtual
        override
        returns (string memory)
    {
        return "";
    }
}

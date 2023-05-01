// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Ownable} from "solady/auth/Ownable.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";
import {IERCDynamicTraitsRegistry} from "./interfaces/IDynamicTraitsRegistry.sol";
import {SignedRedeem} from "./lib/SignedRedeem.sol";

interface IERC721 {
    /// @notice Returns the owner of the token.
    function ownerOf(uint256 tokenId) external view returns (address);
}

contract RedeemableController is SignedRedeem {
    using ECDSA for bytes32;

    mapping(uint256 tokenId => uint256 count) public redeemed;

    /// @dev The trait key for "redeemed"
    bytes32 internal constant _redeemedTraitKey =
        bytes32(abi.encodePacked("redeemed"));

    /// @dev Value for if a token is redeemed (1)
    bytes32 internal constant _REDEEMED = bytes32(abi.encode(1));

    IERCDynamicTraitsRegistry internal immutable _DYNAMIC_TRAITS_REGISTRY;
    IERC721 internal immutable _REDEEMABLE_TOKEN;

    constructor(address dynamicTraitsRegistry, address redeemableToken) {
        _DYNAMIC_TRAITS_REGISTRY = IERCDynamicTraitsRegistry(
            dynamicTraitsRegistry
        );
        _REDEEMABLE_TOKEN = IERC721(redeemableToken);
    }

    function isRedeemed(uint256 tokenId) public view returns (bool) {
        return
            _DYNAMIC_TRAITS_REGISTRY.getTrait(
                address(_REDEEMABLE_TOKEN),
                tokenId,
                _redeemedTraitKey
            ) == _REDEEMED;
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
        require(_REDEEMABLE_TOKEN.ownerOf(tokenId) == msg.sender, "not owner");
        require(!isRedeemed(tokenId), "already redeemed");

        _updateTrait(tokenId, _redeemedTraitKey, _REDEEMED);
    }

    function _updateTrait(
        uint256 tokenId,
        bytes32 traitKey,
        bytes32 newValue
    ) internal {
        _DYNAMIC_TRAITS_REGISTRY.setTrait(
            address(_REDEEMABLE_TOKEN),
            tokenId,
            traitKey,
            newValue
        );
    }
}

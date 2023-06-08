// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC721} from "solady/tokens/ERC721.sol";
import {DynamicTraits} from "./lib/DynamicTraits.sol";
import {SignedRedeem} from "./lib/SignedRedeem.sol";
import {RedeemablesErrorsAndEvents} from "./lib/RedeemableErrorsAndEvents.sol";
import {RedemptionParams} from "./lib/RedeemableStructs.sol";

contract ERC721Redeemable is
    ERC721,
    RedeemablesErrorsAndEvents,
    DynamicTraits,
    SignedRedeem
{
    /// @dev The parameters to redeem a token on this contract.
    RedemptionParams internal _redemptionParams;

    /// @dev The redeemable URI.
    string internal _redeemableURI;

    /// @dev The total redemptions.
    uint256 internal _totalRedemptions;

    bytes32 constant _REDEEMED_TRAIT_KEY = keccak256("redeemedCount");

    constructor() {}

    function redeem(
        uint256[] calldata tokenIds,
        uint256[] calldata amounts,
        bytes calldata signature,
        uint256 salt
    ) public {
        RedemptionParams storage params = _redemptionParams;

        uint256 tokenIdsLength = tokenIds.length;

        if (tokenIdsLength != amounts.length) revert RedeemMismatchedLengths();

        uint256 totalAmount;
        for (uint256 i = 0; i < tokenIdsLength; i++) {
            totalAmount += amounts[i];
        }

        if (_totalRedemptions + totalAmount > params.maxTotalRedemptions)
            revert MaxTotalRedemptionsReached(
                _totalRedemptions + totalAmount,
                params.maxTotalRedemptions
            );

        if (_redeemSigner != address(0)) {
            _verifySignatureAndRecordDigest(
                msg.sender,
                tokenIds,
                salt,
                signature
            );
        }

        for (uint256 i = 0; i < tokenIdsLength; i++) {
            _redeem(tokenIds[i], amounts[i], params.maxRedemptions);
        }

        if (tokenIdsLength == 1) {
            emit Redeemed(tokenIds[0], msg.sender);
        } else {
            emit RedeemedBatch(tokenIds, msg.sender);
        }
    }

    function _redeem(
        uint256 tokenId,
        uint256 amount,
        uint256 maxRedemptions
    ) internal {
        address tokenOwner = ownerOf(tokenId);

        if (
            tokenOwner != msg.sender &&
            !isApprovedForAll(tokenOwner, msg.sender) &&
            getApproved(tokenId) != msg.sender
        ) revert NotOwnerOrApproved();

        uint256 count = redeemedCount(tokenId);

        if (count + amount > maxRedemptions)
            revert MaxRedemptionsReached(count + amount, maxRedemptions);

        _setTrait(tokenId, _REDEEMED_TRAIT_KEY, bytes32(count + amount));
        _totalRedemptions += amount;

        for (uint256 i = 0; i < amount; i++) {
            _burn(tokenId);
        }

        _mint(tokenOwner, tokenId);
    }

    function name() public view virtual override returns (string memory) {
        return "ERC721Redeemable";
    }

    function symbol() public view virtual override returns (string memory) {
        return "EXAMPLE";
    }

    function mint(address to, uint256 tokenId) public onlyOwner {
        _mint(to, tokenId);
    }

    function updateRedemptionParams(
        RedemptionParams memory params
    ) public onlyOwner {
        if (params.redemptionSettingsAreImmutable)
            revert RedemptionSettingsAreImmutable();

        _redemptionParams = params;

        emit RedemptionParamsUpdated(params);
    }

    function updateRedeemableURI(string memory uri) public onlyOwner {
        _redeemableURI = uri;
    }

    function totalRedemptions() external view returns (uint256) {
        return _totalRedemptions;
    }

    function redemptionParams()
        external
        view
        returns (RedemptionParams memory)
    {
        return _redemptionParams;
    }

    function redeemedCount(uint256 tokenId) public view returns (uint256) {
        return uint256(getTrait(tokenId, _REDEEMED_TRAIT_KEY));
    }

    function redeemableURI() external view returns (string memory) {
        return _redeemableURI;
    }

    function tokenURI(
        uint256 /* tokenId */
    ) public view virtual override returns (string memory) {
        return "";
    }
}

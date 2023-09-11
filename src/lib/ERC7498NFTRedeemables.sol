// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC721} from "solady/src/tokens/ERC721.sol";
import {IERC7498} from "../interfaces/IERC7498.sol";
import {IERC721RedemptionMintable} from "../interfaces/IERC721RedemptionMintable.sol";
import {RedeemableErrorsAndEvents} from "./RedeemableErrorsAndEvents.sol";

contract ERC7498NFTRedeemables is ERC721, IERC7498, RedeemableErrorsAndEvents {
    /// @dev The campaign parameters by campaign id.
    mapping(uint256 campaignId => CampaignParams params) private _campaignParams;

    /// @dev The campaign URIs by campaign id.
    mapping(uint256 campaignId => string campaignURI) private _campaignURIs;

    /// @dev The total current redemptions by campaign id.
    mapping(uint256 campaignId => uint256 count) private _totalRedemptions;

    constructor() ERC721() {}

    function name() public pure override returns (string memory) {
        return "ERC7498 NFT Redeemables";
    }

    function symbol() public pure override returns (string memory) {
        return "NFTR";
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {}

    function redeem(uint256[] calldata tokenIds, address recipient, bytes calldata extraData) public {
        // Get the campaign.
        uint256 campaignId = uint256(bytes32(extraData[0:32]));
        CampaignParams storage params = _campaignParams[campaignId];

        // Revert if campaign is inactive.
        if (_isInactive(params.startTime, params.endTime)) {
            revert NotActive(block.timestamp, params.startTime, params.endTime);
        }

        // Revert if max total redemptions would be exceeded.
        if (_totalRedemptions[campaignId] + tokenIds.length > params.maxCampaignRedemptions) {
            revert MaxCampaignRedemptionsReached(_totalRedemptions[campaignId] + 1, params.maxCampaignRedemptions);
        }
        // Iterate over the token IDs and check if caller is the owner or approved operator.
        // Redeem the token if the caller is valid.
        for (uint256 i; i < tokenIds.length;) {
            // Get the identifier.
            uint256 identifier = tokenIds[i];

            // Get the token owner.
            address owner = ownerOf(identifier);

            // Check the caller is either the owner or approved operator.
            if (msg.sender != owner && !isApprovedForAll(owner, msg.sender)) {
                revert InvalidCaller(msg.sender);
            }

            // Burn the token.
            _burn(identifier);

            // Mint the redemption token.
            IERC721RedemptionMintable(params.offer[0].token).mintRedemption(recipient, identifier);

            i++;
        }
    }

    function getCampaign(uint256 campaignId)
        external
        view
        override
        returns (CampaignParams memory params, string memory uri, uint256 totalRedemptions)
    {}

    function createCampaign(CampaignParams calldata params, string calldata uri)
        external
        override
        returns (uint256 campaignId)
    {}

    function updateCampaign(uint256 campaignId, CampaignParams calldata params, string calldata uri)
        external
        override
    {}

    function _checkForRevert(CampaignParams memory params, uint256 campaignId, uint256 errorBuffer) internal {
        if (errorBuffer > 0) {
            if (errorBuffer << 255 != 0) {
                revert NotActive(block.timestamp, params.startTime, params.endTime);
            } else if (errorBuffer << 254 != 0) {
                revert MaxCampaignRedemptionsReached(_totalRedemptions[campaignId] + 1, params.maxCampaignRedemptions);
            } else if (errorBuffer << 253 != 0) {
                revert InvalidCaller(msg.sender);
            }
        }
    }

    /**
     * @dev Internal pure function to cast a `bool` value to a `uint256` value.
     *
     * @param b The `bool` value to cast.
     *
     * @return u The `uint256` value.
     */
    function _cast(bool b) internal pure returns (uint256 u) {
        assembly {
            u := b
        }
    }

    function _isInactive(uint256 startTime, uint256 endTime) internal view returns (bool inactive) {
        // Using the same check for time boundary from Seaport.
        // startTime <= block.timestamp < endTime
        assembly {
            inactive := or(iszero(gt(endTime, timestamp())), gt(startTime, timestamp()))
        }
    }
}

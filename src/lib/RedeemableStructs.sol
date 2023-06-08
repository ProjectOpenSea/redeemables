// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

struct RedemptionParams {
    Item[] requiredToRedeem;
    Item[] receivedOnRedeem;
    address sendRequiredTo;
    address requiredSigner;
    uint32 startTime;
    uint32 endTime;
    uint16 maxRedemptions;
    uint32 maxTotalRedemptions;
    bool redemptionValuesAreImmutable;
    bool redemptionSettingsAreImmutable;
}

struct RedemptionRegistryParams {
    // RedemptionParams
    Item[] requiredToRedeem;
    Item[] receivedOnRedeem;
    address sendRequiredTo;
    address requiredSigner;
    uint32 startTime;
    uint32 endTime;
    uint16 maxRedemptions;
    uint32 maxTotalRedemptions;
    bool redemptionValuesAreImmutable;
    bool redemptionSettingsAreImmutable;
    // Additional parameters for registry functionality
    uint8 mintWithContext;
    address registeredBy;
}

struct Item {
    ItemType itemType;
    address token;
    uint256 identifier;
    uint256 amount;
}

enum ItemType {
    // 0: ETH on mainnet, MATIC on polygon, etc.
    NATIVE,
    // 1: ERC20 items (ERC777 and ERC20 analogues could also technically work)
    ERC20,
    // 2: ERC721 items
    ERC721,
    // 3: ERC1155 items
    ERC1155,
    // 4: Dynamic trait (ERCDynamicTraits)
    TRAIT
}

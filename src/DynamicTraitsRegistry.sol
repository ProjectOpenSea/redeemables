// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ECDSA} from "solady/utils/ECDSA.sol";
import {IERCDynamicTraitsRegistry} from "./interfaces/IDynamicTraitsRegistry.sol";

interface IERC173 {
    /// @notice Returns the address of the owner.
    function owner() external view returns (address);
}

contract DynamicTraitsRegistry is IERCDynamicTraitsRegistry {
    mapping(address token => mapping(uint256 tokenId => mapping(bytes32 traitKey => bytes32 traitValue))) internal
        _traits;

    mapping(address token => address[] operators) internal _allowedOperators;

    function getTrait(address token, uint256 tokenId, bytes32 traitKey)
        external
        view
        virtual
        override
        returns (bytes32)
    {
        return _traits[token][tokenId][traitKey];
    }

    function setTrait(address token, uint256 tokenId, bytes32 traitKey, bytes32 newValue) external {
        _revertIfNotOwnerOrAllowedOperator(token);

        bytes32 oldValue = _traits[token][tokenId][traitKey];
        require(oldValue != newValue, "no change");

        _traits[token][tokenId][traitKey] = newValue;
        emit TraitUpdated(token, tokenId, traitKey, oldValue, newValue);
    }

    function setTraitBulk(address token, uint256 fromTokenId, uint256 toTokenId, bytes32 traitKey, bytes32 newValue)
        external
    {
        _revertIfNotOwnerOrAllowedOperator(token);

        for (uint256 tokenId = fromTokenId; tokenId <= toTokenId; tokenId++) {
            _traits[token][tokenId][traitKey] = newValue;
        }

        emit TraitBulkUpdated(token, fromTokenId, toTokenId, traitKey);
    }

    function updateAllowedOperator(address token, address operator, bool allowed) external {
        require(msg.sender == IERC173(token).owner(), "not owner");
        if (allowed) {
            for (uint256 i = 0; i < _allowedOperators[token].length; i++) {
                require(_allowedOperators[token][i] != operator, "already allowed");
            }
            _allowedOperators[token].push(operator);
            emit OperatorAdded(token, operator);
        } else {
            for (uint256 i = 0; i < _allowedOperators[token].length; i++) {
                if (_allowedOperators[token][i] == operator) {
                    _allowedOperators[token][i] = _allowedOperators[token][_allowedOperators[token].length - 1];
                    _allowedOperators[token].pop();
                    emit OperatorRemoved(token, operator);
                    return;
                }
            }
            revert("not allowed");
        }
    }

    function _revertIfNotOwnerOrAllowedOperator(address token) internal view {
        if (msg.sender == IERC173(token).owner()) return;

        for (uint256 i = 0; i < _allowedOperators[token].length; i++) {
            if (_allowedOperators[token][i] == msg.sender) return;
        }

        revert("not owner or allowed operator");
    }
}

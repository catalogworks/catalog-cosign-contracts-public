// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {RawResult} from "./RawResult.sol";

/**
 * ┌───────────────────────────────────────────────────────────┐
 * │                                                           │
 * │                                                           │
 * │                                                           │
 * │       __  _____  ____  ___________________    __    __    │
 * │      /  |/  / / / / / /_  __/  _/ ____/   |  / /   / /    │
 * │     / /|_/ / / / / /   / /  / // /   / /| | / /   / /     │
 * │    / /  / / /_/ / /___/ / _/ // /___/ ___ |/ /___/ /___   │
 * │   /_/  /_/\____/_____/_/ /___/\____/_/  |_/_____/_____/   │
 * │                                                           │
 * │                                                           │
 * │                                                           │
 * └───────────────────────────────────────────────────────────┘
 */

/// @title MulticallV2
/// @author COMPUTER DATA
/// @notice Enables calling multiple methods in a single call to the contract.
abstract contract MulticallV2 {
    using RawResult for bytes;

    /// @notice Perform multiple delegatecalls in a single transaction.
    /// @param data The data for each delegatecall.
    /// @return results The results of each delegatecall.
    function multicall(bytes[] calldata data) external virtual returns (bytes[] memory results) {
        results = new bytes[](data.length);
        unchecked {
            for (uint256 i = 0; i < data.length;) {
                (bool s, bytes memory r) = address(this).delegatecall(data[i]);
                if (!s) {
                    r.rawRevert();
                } else {
                    results[i] = r;
                }
                ++i;
            }
        }
    }

    /// @notice Perform multiple delegatecalls in a single transaction, for internal use.
    /// @param data The data for each delegatecall.
    /// @return results The results of each delegatecall.
    function _multicallInternal(bytes[] memory data) internal virtual returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i; i < data.length; ++i) {
            (bool s, bytes memory r) = address(this).delegatecall(data[i]);
            if (!s) {
                r.rawRevert();
            } else {
                results[i] = r;
            }
        }
    }
}

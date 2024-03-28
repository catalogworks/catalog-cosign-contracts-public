// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {Base64} from "solady/utils/Base64.sol";

/**
 * ┌──────────────────────────────────────────────────────────┐
 * │                                                          │
 * │                                                          │
 * │                                                          │
 * │                                                          │
 * │                                                          │
 * │                 __  ______  ______    _ __               │
 * │                / / / / __ \/  _/ /   (_) /_              │
 * │               / / / / /_/ // // /   / / __ \             │
 * │              / /_/ / _, _// // /___/ / /_/ /             │
 * │              \____/_/ |_/___/_____/_/_.___/              │
 * │                                                          │
 * │            ┌────────────────────────────────┐            │
 * │            │ Optimized library for storing  │            │
 * │            │         Arweave URI's          │            │
 * │            └────────────────────────────────┘            │
 * │                                                          │
 * └──────────────────────────────────────────────────────────┘
 */

/// @title URILib
/// @author COMPUTER DATA
/// @notice Library for storing and loading arweave URIs efficiently
/// @dev based on @vectorized implementation
library URILib {
    /// @param arweaveURI The arweave URI (compact storage)
    /// @param normal The normal URI in readable string form, can store IPFS, HTTP, etc.
    struct URI {
        bytes32 arweaveURI;
        string normal;
    }

    /// @notice Stores a URI in the URI struct
    /// @param uri The URI struct
    /// @param value The value to store
    /// @param isUpdate Whether or not this is an update to existing stored data
    function storeURI(URI storage uri, string memory value, bool isUpdate) internal {
        uint256 length;
        bool isArweave;

        assembly {
            length := mload(value)

            // check if length is 48 or 49 to account for trailing slashes
            if or(eq(length, 48), eq(length, 49)) {
                // check for "ar://" prefix
                if eq(and(mload(add(value, 5)), 0xffffffffff), 0x61723a2f2f) {
                    isArweave := 1
                    value := add(value, 5)

                    // set length to 43 to ensure it only contains CID
                    mstore(value, 43)
                }
            }
        }

        if (isArweave) {
            bytes memory decodedBytes = Base64.decode(value);
            bytes32 arCID;
            assembly {
                arCID := mload(add(decodedBytes, 0x20))

                // restore "ar://" prefix
                mstore(value, 0x61723a2f2f)

                // restore og position of the value pointer
                value := sub(value, 5)

                // restore og length
                mstore(value, length)
            }
            uri.arweaveURI = arCID;
        } else {
            uri.normal = value;
            if (isUpdate) {
                delete uri.arweaveURI;
            }
        }
    }

    /// @notice Initializes a URI struct
    /// @param uri The URI struct
    /// @param value The value to store
    function initializeURI(URI storage uri, string memory value) internal {
        if (bytes(value).length == 0) return;
        storeURI(uri, value, false);
    }

    /// @notice Updates a URI struct
    /// @param uri The URI struct
    /// @param value The value to store
    function updateURI(URI storage uri, string memory value) internal {
        storeURI(uri, value, true);
    }

    /// @notice Loads a URI from the URI struct
    /// @param uri The URI struct
    /// @return The URI in readable string format
    function loadURI(URI storage uri) internal view returns (string memory) {
        bytes32 arCID = uri.arweaveURI;

        if (arCID == bytes32(0)) {
            return uri.normal;
        }

        bytes memory decodedBytes;

        assembly {
            // get free mem pointer
            decodedBytes := mload(0x40)

            // allocate 2 slots, 1 for length, 1 for bytes
            mstore(0x40, add(decodedBytes, 0x40))
            // 32 bytes length
            mstore(decodedBytes, 0x20)
            mstore(add(decodedBytes, 0x20), arCID)
        }
        return string.concat("ar://", Base64.encode(decodedBytes, true, true));
    }
}

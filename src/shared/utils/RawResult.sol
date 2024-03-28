// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/// @title RawResult
/// @author COMPUTER DATA
/// @notice A library for handling raw revert and return data from external calls.
library RawResult {
    /// @notice reverts with the data in `b`.
    /// @param b The data to revert with.
    function rawRevert(bytes memory b) internal pure {
        assembly {
            revert(add(b, 32), mload(b))
        }
    }

    /// @notice returns with the data in `b`.
    /// @param b The data to return with.
    function rawReturn(bytes memory b) internal pure {
        assembly {
            return(add(b, 32), mload(b))
        }
    }
}

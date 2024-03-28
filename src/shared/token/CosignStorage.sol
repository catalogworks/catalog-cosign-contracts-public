// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {ICosignTypes} from "../interfaces/ICosignTypes.sol";

/**
 * ┌──────────────────────────────────────────────────────────────┐
 * │                                                              │
 * │                                                              │
 * │                                                              │
 * │                __________  _____ ___________   __            │
 * │               / ____/ __ \/ ___//  _/ ____/ | / /            │
 * │              / /   / / / /\__ \ / // / __/  |/ /             │
 * │             / /___/ /_/ /___/ // // /_/ / /|  /              │
 * │             \____/\____//____/___/\____/_/ |_/               │
 * │                                                              │
 * │            _______________  ____  ___   ____________         │
 * │           / ___/_  __/ __ \/ __ \/   | / ____/ ____/         │
 * │           \__ \ / / / / / / /_/ / /| |/ / __/ __/            │
 * │          ___/ // / / /_/ / _, _/ ___ / /_/ / /___            │
 * │         /____//_/  \____/_/ |_/_/  |_\____/_____/            │
 * │                                                              │
 * │                                                              │
 * │                                                              │
 * │                                                              │
 * └──────────────────────────────────────────────────────────────┘
 */

/// @title CosignStorage
/// @author COMPUTER DATA
/// @notice storage contract for Cosign token contract
contract CosignStorage is ICosignTypes {
    /*//////////////////////////////////////////////////////////////
                                  STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice mapping tokenId to referral reward percentage
    mapping(uint256 => uint256) public referralRewards;

    /// @notice token data for each token
    mapping(uint256 => TokenData) internal tokens;

    /// @notice auth bitmask
    mapping(address => uint256) public authPermissions;

    // @notice contract traditional metadata storage
    ContractMetadata public contractMetadata;

    // @notice receiver address for platform fees
    address public platformFeeRecipient;

    // @notice token price in wei
    uint256 internal TOKEN_PRICE;

    // @notice artist fee percentage (0-100)
    uint8 internal ARTIST_FEE;

    // @notice platform fee percentage (0-100)
    uint8 internal PLATFORM_FEE;
}

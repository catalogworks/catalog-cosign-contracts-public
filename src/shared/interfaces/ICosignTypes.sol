// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {URILib} from "../storage/URILib.sol";

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
 * │                  ________  ______  ___________               │
 * │                 /_  __/\ \/ / __ \/ ____/ ___/               │
 * │                  / /    \  / /_/ / __/  \__ \                │
 * │                 / /     / / ____/ /___ ___/ /                │
 * │                /_/     /_/_/   /_____//____/                 │
 * │                                                              │
 * │                                                              │
 * │                                                              │
 * │                                                              │
 * └──────────────────────────────────────────────────────────────┘
 */

/// @title ICosignTypes
/// @author COMPUTER DATA
/// @notice type interface for Cosigns
interface ICosignTypes {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error Unauthorized();
    error InvalidTokenId();
    error IncorrectValue();
    error InvalidRewardPercentage();
    error InvalidFeePercentage();
    error TokenAlreadyExists();
    error TransfersNotAllowed();
    error ApprovalsNotAllowed();
    error TokenIdOverflow();
    error InvalidAddress();
    error PaymentFailed(address recipient, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/
    /// @notice token data for each token
    /// @param artist The address of the artist
    /// @param artistPayoutAddress The address to send artist royalties to
    /// @param contentHash The content hash of the token
    /// @param uri The URI of the token

    struct TokenData {
        address artist;
        address artistPayoutAddress;
        bytes32 contentHash;
        URILib.URI uri;
    }

    /// @notice input data for creating a token
    /// @param artist The address of the artist
    /// @param artistPayoutAddress The address to send artist royalties to
    /// @param L1ContractAddress The address of the L1 contract
    /// @param contentHash The content hash of the token
    /// @param L1TokenId The L1 token ID
    /// @param uri The URI of the token
    struct InputTokenData {
        address artist;
        address artistPayoutAddress;
        address L1ContractAddress;
        bytes32 contentHash;
        uint256 L1TokenId;
        string uri;
    }

    /// @notice input initialization data for the contract
    /// @param _owner The owner of the contract
    /// @param _artistShare The percentage of royalties to send to the artist
    /// @param _platformShare The percentage of royalties to send to the platform
    /// @param _name The name of the contract
    /// @param _symbol The symbol of the contract
    /// @param _contractMetadataURI The URI of the contract metadata
    struct CosignInitData {
        address _owner;
        uint256 _artistShare;
        uint256 _platformShare;
        string _name;
        string _contractMetadataURI;
    }

    /// @notice struct for contract metadata
    /// @param name The name of the contract
    struct ContractMetadata {
        string name;
    }
}

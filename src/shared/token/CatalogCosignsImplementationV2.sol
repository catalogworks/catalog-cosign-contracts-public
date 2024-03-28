// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {CosignStorage} from "./CosignStorage.sol";
import {URILib} from "../storage/URILib.sol";
import {MulticallV2} from "../utils/MulticallV2.sol";

/**
 * ┌──────────────────────────────────────────────────────────────────────────┐
 * │                                                                          │
 * │                                                                          │
 * │                                                                          │
 * │                                                                          │
 * │                                                                          │
 * │                                                                          │
 * │                                                                          │
 * │     .oooooo.                 .             oooo                          │
 * │    d8P'  `Y8b              .o8             `888                          │
 * │   888           .oooo.   .o888oo  .oooo.    888   .ooooo.   .oooooooo    │
 * │   888          `P  )88b    888   `P  )88b   888  d88' `88b 888' `88b     │
 * │   888           .oP"888    888    .oP"888   888  888   888 888   888     │
 * │   `88b    ooo  d8(  888    888 . d8(  888   888  888   888 `88bod8P'     │
 * │    `Y8bood8P'  `Y888""8o   "888" `Y888""8o o888o `Y8bod8P' `8oooooo.     │
 * │                                                            d"     YD     │
 * │                                                            "Y88888P'     │
 * │                                                                          │
 * │    .oooooo.                       o8o                                    │
 * │   d8P'  `Y8b                      `"'                                    │
 * │  888           .ooooo.   .oooo.o oooo   .oooooooo ooo. .oo.    .oooo.o   │
 * │  888          d88' `88b d88(  "8 `888  888' `88b  `888P"Y88b  d88(  "8   │
 * │  888          888   888 `"Y88b.   888  888   888   888   888  `"Y88b.    │
 * │  `88b    ooo  888   888 o.  )88b  888  `88bod8P'   888   888  o.  )88b   │
 * │   `Y8bood8P'  `Y8bod8P' 8""888P' o888o `8oooooo.  o888o o888o 8""888P'   │
 * │                                        d"     YD                         │
 * │                                        "Y88888P'                         │
 * │                                                                          │
 * │                                                                          │
 * │                                                                          │
 * │                   ┌────────────────────────────────┐                     │
 * │                   │ SHARED COLLECTION UPGRADEABLE  │                     │
 * │                   └────────────────────────────────┘                     │
 * │                                   V2                                     │
 * │                                                                          │
 * └──────────────────────────────────────────────────────────────────────────┘
 */

/**
 * @title CatalogCosignsImplementation
 * @author COMPUTER DATA
 * @notice Implementation of the Cosign Catalog Shared Collection (ERC-1155) - UUPS Proxied Upgradeable
 * @dev Uses nonlinear tokenId structure. 0 is reserved for contract metadata. TokenIds are computed from 1:1 contract:tokenId pairs
 * @custom:warning Cosign tokens are non-transferrable. Transfers and approvals are disabled.
 */
contract CatalogCosignsImplementation is
    Initializable,
    Ownable2StepUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    ERC1155Upgradeable,
    CosignStorage,
    MulticallV2
{
    using URILib for URILib.URI;

    /*//////////////////////////////////////////////////////////////
                                  STATE
    //////////////////////////////////////////////////////////////*/
    // @notice contract metadata storage tokenId
    uint256 public immutable CONTRACT_BASE_ID = 0;
    // @notice admin bitmask
    uint16 public immutable AUTH_ADMIN = 2 ** 1;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event TokenMinted(uint256 indexed tokenId, address indexed artist, uint256 amount);
    event TokenPurchased(
        uint256 indexed tokenId, uint256 indexed amount, address indexed buyer, address referrer0, address referrer1
    );
    event TokenCreated(
        uint256 indexed _tokenId, address _contract, address indexed _artist, string _uri, bytes32 indexed _contentHash
    );
    event TokenPayoutAddressUpdated(uint256 indexed tokenId, address indexed payoutAddress);
    event ReferralRewardUpdated(uint256 indexed tokenId, uint256 indexed rewardBPS);
    event FeesUpdated(uint256 indexed artistFee, uint256 indexed platformFee);
    event TokenPriceUpdated(uint256 indexed tokenPrice);
    event PlatformFeeRecipientUpdated(address indexed platformFeeRecipient);
    event PermissionUpdated(address indexed admin, uint256 indexed authScope);

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyAdmin() {
        if (msg.sender != owner() && authPermissions[msg.sender] != AUTH_ADMIN) {
            revert Unauthorized();
        }
        _;
    }

    modifier onlyArtistOrAdmin(uint256 _tokenId) {
        TokenData memory tokenData = tokens[_tokenId];
        if (msg.sender != tokenData.artist && authPermissions[msg.sender] != AUTH_ADMIN && msg.sender != owner()) {
            revert Unauthorized();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice placeholder constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice proxy initializer
    /// @param initData input calldata struct (see CosignInitData struct in ICosignTypes)
    function initialize(CosignInitData calldata initData) public initializer {
        if (msg.sender != initData._owner) {
            revert Unauthorized();
        }

        contractMetadata = ContractMetadata({name: initData._name});

        __UUPSUpgradeable_init();
        __Ownable_init(initData._owner);
        __ERC1155_init("");

        platformFeeRecipient = owner();
        ARTIST_FEE = uint8(initData._artistShare);
        PLATFORM_FEE = uint8(initData._platformShare);
        // default init price is 0.001 ether
        TOKEN_PRICE = 0.001 ether;

        _setupDefaultToken(initData._contractMetadataURI);

        emit FeesUpdated(ARTIST_FEE, PLATFORM_FEE);
        emit TokenPriceUpdated(TOKEN_PRICE);
    }

    /*//////////////////////////////////////////////////////////////
                             EXTERNAL WRITE
    //////////////////////////////////////////////////////////////*/

    /// @notice mint a new token without cost, restricted for artist/owner usage
    /// @param _artist address of the artist
    /// @param _tokenId id of the token to mint
    /// @param _amount number of tokens to mint
    /// @param _data bytes data, required for ERC1155 receiver callback
    function mintTokenAdmin(address _artist, uint256 _tokenId, uint256 _amount, bytes calldata _data)
        external
        nonReentrant
        onlyArtistOrAdmin(_tokenId)
    {
        if (_tokenId == CONTRACT_BASE_ID) {
            revert InvalidTokenId();
        }
        _mintInternal(_artist, _tokenId, _amount, _data);
        emit TokenMinted(_tokenId, _artist, _amount);
    }

    /// @notice mint a token via purchase with ETH
    /// @param _tokenId id of the token to mint
    /// @param _amount number of tokens to mint
    /// @param _ref0 optional 1st referral address, if referral rewards are enabled. use address(0) if not.
    /// @param _ref1 optional 2nd referral address, if referral rewards are enabled. use address(0) if not.
    function purchaseToken(uint256 _tokenId, uint256 _amount, address _ref0, address _ref1)
        external
        payable
        nonReentrant
    {
        if (_tokenId == CONTRACT_BASE_ID) {
            revert InvalidTokenId();
        }

        uint256 TOTAL_PRICE = TOKEN_PRICE * _amount;
        if (msg.value != TOTAL_PRICE) {
            revert IncorrectValue();
        }

        _handlePayment(_tokenId, msg.value, _ref0, _ref1);

        _mintInternal(msg.sender, _tokenId, _amount, "");

        emit TokenPurchased(_tokenId, _amount, msg.sender, _ref0, _ref1);
    }

    /// @notice mint a token via purchase with ETH and send to an input recipient
    /// @param _tokenId id of the token to mint
    /// @param _amount number of tokens to mint
    /// @param _recipient address to send the tokens to
    /// @param _ref0 optional 1st referral address, if referral rewards are enabled. use address(0) if not.
    /// @param _ref1 optional 2nd referral address, if referral rewards are enabled. use address(0) if not.
    /// @dev this function emits a TokenPurchased event with the recipient as the "buyer". The original buyer is available from the transactions msg.sender
    function purchaseTokenForRecipient(
        uint256 _tokenId,
        uint256 _amount,
        address _recipient,
        address _ref0,
        address _ref1
    ) external payable nonReentrant {
        if (_tokenId == CONTRACT_BASE_ID) {
            revert InvalidTokenId();
        }

        if (_recipient == address(0)) {
            revert InvalidAddress();
        }

        uint256 TOTAL_PRICE = TOKEN_PRICE * _amount;
        if (msg.value != TOTAL_PRICE) {
            revert IncorrectValue();
        }

        _handlePayment(_tokenId, msg.value, _ref0, _ref1);

        _mintInternal(_recipient, _tokenId, _amount, "");

        emit TokenPurchased(_tokenId, _amount, _recipient, _ref0, _ref1);
    }

    /// @notice set the referral reward for a given token
    /// @param _tokenId id of the token to set rewards for
    /// @param _rewardBPS the reward in percentage
    /// @dev 10 = 10%; retricted to admin or token artist
    function setReferralReward(uint256 _tokenId, uint256 _rewardBPS) external onlyArtistOrAdmin(_tokenId) {
        if (_tokenId == CONTRACT_BASE_ID) {
            revert InvalidTokenId();
        }
        if (_rewardBPS > ARTIST_FEE) {
            revert InvalidRewardPercentage();
        }
        referralRewards[_tokenId] = _rewardBPS;
        emit ReferralRewardUpdated(_tokenId, _rewardBPS);
    }

    /// @notice setup a new tokenId, making it available for purchase/mint
    /// @param _input the input calldata struct (see InputTokenData struct in ICosignTypes)
    /// @param _referralRewardBPS the referral reward in percentage (use 0 for no referral reward)
    /// @return tokenId the id of the token
    /// @dev access restricted to contract owner/admin
    function setupToken(InputTokenData calldata _input, uint256 _referralRewardBPS)
        external
        onlyAdmin
        returns (uint256 tokenId)
    {
        if (_input.artistPayoutAddress == address(0) || _input.artist == address(0)) {
            revert InvalidAddress();
        }
        if (_referralRewardBPS > ARTIST_FEE) {
            revert InvalidRewardPercentage();
        }

        tokenId = _encodeTokenId(_input.L1ContractAddress, _input.L1TokenId);
        if (tokens[tokenId].artist != address(0)) {
            revert TokenAlreadyExists();
        }

        TokenData storage tokenData = tokens[tokenId];
        tokenData.artist = _input.artist;
        tokenData.artistPayoutAddress = _input.artistPayoutAddress;
        tokenData.contentHash = _input.contentHash;
        tokenData.uri.initializeURI(_input.uri);

        if (_referralRewardBPS > 0) {
            referralRewards[tokenId] = _referralRewardBPS;
            emit ReferralRewardUpdated(tokenId, _referralRewardBPS);
        }

        emit TokenCreated(tokenId, _input.L1ContractAddress, _input.artist, _input.uri, _input.contentHash);

        return tokenId;
    }

    /// @notice update the metadata for an existing token
    /// @param _tokenId the id of the token to update
    /// @param _uri the new metadata uri for the token
    function updateTokenURI(uint256 _tokenId, string calldata _uri) external onlyArtistOrAdmin(_tokenId) {
        if (_tokenId == CONTRACT_BASE_ID) {
            revert InvalidTokenId();
        }
        TokenData storage tokenData = tokens[_tokenId];
        tokenData.uri.updateURI(_uri);

        emit URI(_uri, _tokenId);
    }

    /// @notice update the payout address for an existing token
    /// @param _tokenId the id of the token to update
    /// @param _artistPayoutAddress the new payout address for the token
    /// @dev access restricted to contract owner/token artist
    function updateTokenArtistPayoutAddress(uint256 _tokenId, address _artistPayoutAddress)
        external
        onlyArtistOrAdmin(_tokenId)
    {
        if (_tokenId == CONTRACT_BASE_ID) {
            revert InvalidTokenId();
        }

        if (_artistPayoutAddress == address(0)) {
            revert InvalidAddress();
        }

        TokenData storage tokenData = tokens[_tokenId];

        tokenData.artistPayoutAddress = _artistPayoutAddress;
        emit TokenPayoutAddressUpdated(_tokenId, _artistPayoutAddress);
    }

    /// @notice update the contract metadata uri
    /// @param _uri the new contract metadata uri
    /// @dev access restricted to contract owner
    function updateContractURI(string calldata _uri) external onlyOwner {
        _updateContractURI(_uri);
        emit URI(_uri, CONTRACT_BASE_ID);
    }

    /// @notice update the platform fee percentage
    /// @param _artistFee the new artist fee percentage
    /// @param _platformFee the new platform fee percentage
    /// @dev access restricted to contract owner
    function setFees(uint256 _artistFee, uint256 _platformFee) external onlyOwner {
        if (_artistFee + _platformFee != 100) {
            revert InvalidFeePercentage();
        }
        ARTIST_FEE = uint8(_artistFee);
        PLATFORM_FEE = uint8(_platformFee);
        emit FeesUpdated(ARTIST_FEE, PLATFORM_FEE);
    }

    /// @notice update the platform fee recipient
    /// @param _platformFeeRecipient the new platform fee recipient
    /// @dev access restricted to contract owner
    function setPlatformFeeRecipient(address _platformFeeRecipient) external onlyOwner {
        if (_platformFeeRecipient == address(0)) {
            revert InvalidAddress();
        }
        platformFeeRecipient = _platformFeeRecipient;
        emit PlatformFeeRecipientUpdated(_platformFeeRecipient);
    }

    /// @notice update the admin permissions for a given address
    /// @param _admin the address to update permissions for
    /// @param _authScope the new auth scope for the address
    /// @dev access restricted to contract owner
    function setAdminPermission(address _admin, uint256 _authScope) external onlyOwner {
        authPermissions[_admin] = _authScope;
        emit PermissionUpdated(_admin, _authScope);
    }

    /// @notice update the token price
    /// @param _tokenPrice the new token price
    /// @dev access restricted to contract owner
    function setTokenPrice(uint256 _tokenPrice) external onlyOwner {
        TOKEN_PRICE = _tokenPrice;
        emit TokenPriceUpdated(TOKEN_PRICE);
    }

    /*//////////////////////////////////////////////////////////////
                             INTERNAL WRITE
    //////////////////////////////////////////////////////////////*/

    /// @notice internal helper function to handle payments
    /// @param _tokenId the id of the token being purchased
    /// @param _value the value of the payment
    /// @param _ref0 the first referral address
    /// @param _ref1 the second referral address
    function _handlePayment(uint256 _tokenId, uint256 _value, address _ref0, address _ref1) internal {
        uint256 platformShare = (_value * PLATFORM_FEE) / 100;

        // retrieve token data for artist's payout address and referral reward
        TokenData memory tokenData = tokens[_tokenId];
        uint256 referralReward = referralRewards[_tokenId];
        if (tokenData.artistPayoutAddress == address(0)) {
            revert InvalidTokenId();
        }

        // calculate the artist's share of the payment
        uint256 artistShare = (_value * ARTIST_FEE) / 100;

        uint256 referralShare = 0;

        // calculate the referral share if applicable
        if (referralReward > 0) {
            referralShare = (_value * referralReward) / 100;
            // deduct the referral share from the artist's share
            artistShare -= referralShare;

            // distribute referral share
            if (_ref0 != address(0) && _ref0 != tokenData.artistPayoutAddress) {
                uint256 ref0Share =
                    _ref1 == address(0) || _ref1 == tokenData.artistPayoutAddress ? referralShare : referralShare / 2;
                _safeTransferETH(_ref0, ref0Share);
            }

            // if there's a second referral, distribute the second half of the referral share
            if (_ref1 != address(0) && _ref1 != tokenData.artistPayoutAddress && _ref0 != _ref1) {
                uint256 ref1Share = referralShare / 2;
                _safeTransferETH(_ref1, ref1Share);
            }
        }

        // transfer the platform's share
        _safeTransferETH(platformFeeRecipient, platformShare);

        // transfer the artist's share
        _safeTransferETH(tokenData.artistPayoutAddress, artistShare);
    }

    /// @notice internal helper function to safely transfer ETH
    /// @param _recipient the address to send ETH to
    /// @param _amount the amount of ETH to send
    /// @dev reverts if the transfer fails
    function _safeTransferETH(address _recipient, uint256 _amount) internal {
        // skip if no amount to transfer or if recipient is zero address
        if (_amount == 0 || _recipient == address(0)) return;
        (bool success,) = _recipient.call{value: _amount}("");
        if (!success) {
            revert PaymentFailed(_recipient, _amount);
        }
    }

    /// @notice transfers are not allowed
    function _transfer(address, address, uint256, uint256, bytes memory) internal pure {
        revert TransfersNotAllowed();
    }

    /// @notice internal helper function to mint tokens
    function _mintInternal(address to, uint256 id, uint256 amount, bytes memory data) internal {
        super._mint(to, id, amount, data);
    }

    /// @notice internal helper function for initializing token 0 (contract metadata)
    /// @param _uri the metadata uri for the token/contract
    function _setupDefaultToken(string memory _uri) internal {
        TokenData storage tokenData = tokens[CONTRACT_BASE_ID];
        tokenData.uri.initializeURI(_uri);
        tokenData.artist = address(0);
        tokenData.artistPayoutAddress = address(0);
        tokenData.contentHash = bytes32(0);
    }

    /// @notice internal helper function to update the contract metadata uri
    /// @param _uri the contract metadata uri
    function _updateContractURI(string memory _uri) internal {
        TokenData storage tokenData = tokens[CONTRACT_BASE_ID];
        tokenData.uri.updateURI(_uri);
    }

    // @notice no-op
    function _setURI(string memory newuri) internal virtual override {}

    /*//////////////////////////////////////////////////////////////
                              PUBLIC WRITE
    //////////////////////////////////////////////////////////////*/

    /// @notice transfers are not allowed
    function safeTransferFrom(address, address, uint256, uint256, bytes memory) public pure override {
        revert TransfersNotAllowed();
    }

    /// @notice transfers are not allowed
    function safeBatchTransferFrom(address, address, uint256[] memory, uint256[] memory, bytes memory)
        public
        pure
        override
    {
        revert TransfersNotAllowed();
    }

    /// @notice transfers are not allowed
    function setApprovalForAll(address, bool) public pure override {
        revert ApprovalsNotAllowed();
    }

    /// @notice withdraw function to extract ETH from the contract
    /// @dev access restricted to contract owner
    function withdraw() public onlyOwner {
        uint256 bal = address(this).balance;
        _safeTransferETH(platformFeeRecipient, bal);
    }

    /*//////////////////////////////////////////////////////////////
                               PUBLIC READ
    //////////////////////////////////////////////////////////////*/

    /// @notice returns the URI for an individual token
    /// @param _id the id of the token
    /// @return uri the metadata uri for the token
    function uri(uint256 _id) public view virtual override returns (string memory) {
        TokenData storage tokenData = tokens[_id];
        return tokenData.uri.loadURI();
    }

    /*//////////////////////////////////////////////////////////////
                              EXTERNAL READ
    //////////////////////////////////////////////////////////////*/

    /// @notice returns the TokenData struct for a given token
    /// @param _tokenId the id of the token
    /// @return TokenData the TokenData struct
    function tokenInfo(uint256 _tokenId) external view returns (TokenData memory) {
        TokenData memory tokenData = tokens[_tokenId];
        return tokenData;
    }

    /// @notice returns the TokenData struct for a given contract/tokenId pair
    /// @param _L1TokenId the tokenId of the token
    /// @param _L1ContractAddress the address of the contract
    /// @return TokenData the TokenData struct
    function tokenInfoByRecord(uint256 _L1TokenId, address _L1ContractAddress)
        external
        view
        returns (TokenData memory)
    {
        uint256 tokenId = _encodeTokenId(_L1ContractAddress, _L1TokenId);
        TokenData memory tokenData = tokens[tokenId];
        return tokenData;
    }

    /// @notice returns the contract name
    function contractName() external view returns (string memory) {
        return contractMetadata.name;
    }

    /// @notice returns the contract metadata URI (from tokenId 0)
    function contractURI() external view returns (string memory) {
        TokenData storage tokenData = tokens[CONTRACT_BASE_ID];
        return tokenData.uri.loadURI();
    }

    /// @notice returns the current price for purchasing a cosign token
    /// @return price the token price in wei
    function tokenPrice() external view returns (uint256) {
        return TOKEN_PRICE;
    }

    /// @notice returns the current platform fee percentage
    function platformFee() external view returns (uint256) {
        return PLATFORM_FEE;
    }

    /// @notice returns the current artist fee percentage
    function artistFee() external view returns (uint256) {
        return ARTIST_FEE;
    }

    /// @notice returns the calculated deterministic tokenId for a given contract/tokenId pair
    /// @param _contract address of the contract
    /// @param _tokenId tokenId of the token
    /// @dev this is a helper function for clients to calculate tokenIds for 1:1 tokens, does not check if the token exists
    function getTokenId(address _contract, uint256 _tokenId) external pure returns (uint256) {
        return _encodeTokenId(_contract, _tokenId);
    }

    /// @notice returns the contract address and tokenId for a given cosign tokenId
    /// @param _tokenId the cosign tokenId
    /// @return address the L1 contract address
    /// @return uint256 the L1 token ID
    function getL1Details(uint256 _tokenId) external pure returns (address, uint256) {
        return _decodeTokenId(_tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                              INTERNAL READ
    //////////////////////////////////////////////////////////////*/

    /// @notice used by UUPS upgradeable proxy to check if sender is authorized to upgrade
    function _authorizeUpgrade(address _newImpl) internal view override onlyAdmin {}

    /// @notice encodes a contract address and token ID into a single uint256
    /// @param _contract contract address
    /// @param _tokenId  token ID
    /// @return uint256 the encoded token ID
    /// @dev maximum input token ID is 2^96 - 1 (79,228,162,514,264,337,593,543,950,335).
    function _encodeTokenId(address _contract, uint256 _tokenId) internal pure returns (uint256) {
        if (_tokenId != (_tokenId & ((1 << 96) - 1))) {
            revert TokenIdOverflow();
        }
        // shift the address 96 bits to the left and OR it with the token ID
        return (uint256(uint160(_contract)) << 96) | _tokenId;
    }

    /// @notice decodes a token ID into its L1 contract address and L1 tokenID components
    /// @param _encodedId the encoded cosign token ID
    /// @return address the L1 contract address
    /// @return uint256 the L1 token ID
    function _decodeTokenId(uint256 _encodedId) internal pure returns (address, uint256) {
        address contractAddress = address(uint160(_encodedId >> 96));
        uint256 tokenId = _encodedId & ((1 << 96) - 1);
        return (contractAddress, tokenId);
    }
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.17;

import {Test, console2} from "forge-std/Test.sol";
import {CatalogCosignsImplementation} from "../src/shared/token/CatalogCosignsImplementation.sol";
import {ICosignTypes} from "../src/shared/interfaces/ICosignTypes.sol";
import {CatalogCosigns} from "../src/shared/proxies/CatalogCosigns.sol";

contract TestUpgradeSepolia is Test {
    CatalogCosignsImplementation internal tokenContract;
    CatalogCosigns internal proxyContract;

    uint256 internal signerPrivateKey;
    uint256 internal actorPrivateKey;
    uint256 internal personPrivateKey;

    // fork identifiers
    uint256 internal optimismSepoliaFork;

    address internal signer;
    address internal actor;
    address internal person;
    address internal catalog;
    address internal dogalog;

    address proxyOwner = 0x5E164cC585f79EEf376bD76c867674f9E0f00722;

    address internal immutable catalogContractAddress = 0x0bC2A24ce568DAd89691116d5B34DEB6C203F342;
    address internal immutable catalogOPSafeAddress = 0x558a128757DEDCF3543f764aD61383fdeb11dB2E;

    // @notice helper function
    function bytesToUint256(bytes memory b) public pure returns (uint256) {
        require(b.length == 32, "The bytes array must be 32 bytes long");
        uint256 num;
        assembly {
            num := mload(add(b, 32))
        }
        return num;
    }

    function setUp() public {
        string memory OPTIMISM_SEPOLIA_RPC_URL = vm.envString("OPTIMISM_SEPOLIA_RPC");
        optimismSepoliaFork = vm.createFork(OPTIMISM_SEPOLIA_RPC_URL);

        catalog = makeAddr("catalog");
        dogalog = makeAddr("dogalog");

        signerPrivateKey = 0xA11CE;
        actorPrivateKey = 0xBAD;
        personPrivateKey = 0x1234;

        signer = vm.addr(signerPrivateKey);
        actor = vm.addr(actorPrivateKey);
        person = vm.addr(personPrivateKey);

        // deployed V1
        proxyContract = CatalogCosigns(payable(address(0x0656d93076AF4b43a82f0952806c19B13983d5a7)));
    }

    function testUpgrade() public {
        vm.selectFork(optimismSepoliaFork);
        CatalogCosignsImplementation implementationV1 = CatalogCosignsImplementation(address(proxyContract));

        // check storage variables first

        address ogPlatformFeeRecipient = CatalogCosignsImplementation(address(proxyContract)).platformFeeRecipient();
        uint256 ogContractBaseId = CatalogCosignsImplementation(address(proxyContract)).CONTRACT_BASE_ID();
        uint256 ogTokenPrice = CatalogCosignsImplementation(address(proxyContract)).tokenPrice();
        uint16 ogAuthAdmin = CatalogCosignsImplementation(address(proxyContract)).AUTH_ADMIN();
        uint256 ogArtistFee = CatalogCosignsImplementation(address(proxyContract)).artistFee();
        uint256 ogPlatformFee = CatalogCosignsImplementation(address(proxyContract)).platformFee();

        // get tokenId for 562
        uint256 og562TokenId = CatalogCosignsImplementation(address(proxyContract)).getTokenId(
            0x0bC2A24ce568DAd89691116d5B34DEB6C203F342, 562
        );

        ICosignTypes.TokenData memory og562TokenData =
            CatalogCosignsImplementation(address(proxyContract)).tokenInfo(og562TokenId);
        string memory og562URI = CatalogCosignsImplementation(address(proxyContract)).uri(og562TokenId);
        string memory ogContractMetadata = CatalogCosignsImplementation(address(proxyContract)).contractName();

        // deploy V2
        vm.startPrank(proxyOwner);

        vm.deal(proxyOwner, 2 ether);

        CatalogCosignsImplementation implementationV2 = new CatalogCosignsImplementation();

        // upgrade
        implementationV1.upgradeToAndCall(address(implementationV2), "");

        // check storage variables after upgrade

        address newPlatformFeeRecipient = CatalogCosignsImplementation(address(proxyContract)).platformFeeRecipient();
        uint256 newContractBaseId = CatalogCosignsImplementation(address(proxyContract)).CONTRACT_BASE_ID();
        uint256 newTokenPrice = CatalogCosignsImplementation(address(proxyContract)).tokenPrice();
        uint16 newAuthAdmin = CatalogCosignsImplementation(address(proxyContract)).AUTH_ADMIN();
        uint256 newArtistFee = CatalogCosignsImplementation(address(proxyContract)).artistFee();
        uint256 newPlatformFee = CatalogCosignsImplementation(address(proxyContract)).platformFee();

        // get tokenId for 562
        uint256 new562TokenId = CatalogCosignsImplementation(address(proxyContract)).getTokenId(
            0x0bC2A24ce568DAd89691116d5B34DEB6C203F342, 562
        );

        ICosignTypes.TokenData memory new562TokenData =
            CatalogCosignsImplementation(address(proxyContract)).tokenInfo(new562TokenId);
        string memory new562URI = CatalogCosignsImplementation(address(proxyContract)).uri(new562TokenId);

        string memory newContractMetadata = CatalogCosignsImplementation(address(proxyContract)).contractName();

        // check storage variables

        // assertEq(ogPlatformFeeRecipient, newPlatformFeeRecipient);
        // assertEq(ogContractBaseId, newContractBaseId);
        // assertEq(ogTokenPrice, newTokenPrice);
        // assertEq(ogAuthAdmin, newAuthAdmin);
        // assertEq(ogArtistFee, newArtistFee);
        // assertEq(ogPlatformFee, newPlatformFee);

        // assertEq(og562TokenData.artist, new562TokenData.artist);
        // assertEq(og562TokenData.artistPayoutAddress, new562TokenData.artistPayoutAddress);
        // assertEq(og562TokenData.contentHash, new562TokenData.contentHash);
        // assertEq(og562URI, new562URI);
        // assertEq(ogContractMetadata, newContractMetadata);
    }
}

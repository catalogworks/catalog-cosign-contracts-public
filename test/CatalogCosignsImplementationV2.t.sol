// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Test, console2} from "forge-std/Test.sol";
import {CatalogCosignsImplementation} from "../src/shared/token/CatalogCosignsImplementationV2.sol";
import {ICosignTypes} from "../src/shared/interfaces/ICosignTypes.sol";
import {CatalogCosigns} from "../src/shared/proxies/CatalogCosigns.sol";
import {IOptimismGasOracle} from "./utils/IOptimismGasOracle.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {MockTransferRejector} from "./mocks/MockTransferRejector.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {MockERC1155Rejector} from "./mocks/MockERC1155Rejector.sol";

contract CatalogCosignsImplementationTestV2 is Test {
    CatalogCosignsImplementation internal tokenContract;
    CatalogCosigns internal proxyContract;
    IOptimismGasOracle internal gasOracle;

    MockTransferRejector internal mockTransferRejector;
    MockERC1155Rejector internal mockERC1155Rejector;

    uint256 internal signerPrivateKey;
    uint256 internal actorPrivateKey;
    uint256 internal personPrivateKey;

    // fork identifiers
    // uint256 internal optimismMainnetFork;
    // uint256 internal optimismGoerliFork;

    address internal signer;
    address internal actor;
    address internal person;
    address internal catalog;
    address internal dogalog;
    address internal receiver;

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
        // string memory OPTIMISM_MAINNET_RPC_URL = vm.envString("OPTIMISM_MAINNET_RPC");

        catalog = makeAddr("catalog");
        dogalog = makeAddr("dogalog");
        receiver = makeAddr("receiver");

        signerPrivateKey = 0xA11CE;
        actorPrivateKey = 0xBAD;
        personPrivateKey = 0x1234;

        signer = vm.addr(signerPrivateKey);
        actor = vm.addr(actorPrivateKey);
        person = vm.addr(personPrivateKey);

        CatalogCosignsImplementation CSCLGV4Implementation = new CatalogCosignsImplementation();

        vm.startPrank(catalog);

        proxyContract = new CatalogCosigns(address(CSCLGV4Implementation));
        CatalogCosignsImplementation(address(proxyContract)).initialize(
            ICosignTypes.CosignInitData({
                _owner: address(catalog),
                _artistShare: 85,
                _platformShare: 15,
                _name: "name",
                _contractMetadataURI: ""
            })
        );

        gasOracle = IOptimismGasOracle(address(0x420000000000000000000000000000000000000F));
        mockTransferRejector = new MockTransferRejector();
        mockERC1155Rejector = new MockERC1155Rejector();

        vm.stopPrank();

        // optimismMainnetFork = vm.createFork(OPTIMISM_MAINNET_RPC_URL);
    }

    function test_RevertUnauthorizedInit() public {
        CatalogCosignsImplementation implementationTest = new CatalogCosignsImplementation();
        vm.startPrank(catalog);
        CatalogCosigns proxyTest = new CatalogCosigns(address(implementationTest));

        vm.expectRevert(ICosignTypes.Unauthorized.selector);
        CatalogCosignsImplementation(address(proxyTest)).initialize(
            ICosignTypes.CosignInitData({
                _owner: address(dogalog),
                _artistShare: 85,
                _platformShare: 15,
                _name: "name",
                _contractMetadataURI: ""
            })
        );
    }

    function test_InvariantTotalShare() public {
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        uint256 artistShare = cosignContract.artistFee();
        uint256 platformShare = cosignContract.platformFee();
        assertEq(artistShare + platformShare, 100, "Invariant failed: Total share does not equal 100");
    }

    function test_SetupTokenBasic() public {
        assertEq(CatalogCosignsImplementation(address(proxyContract)).contractName(), "name");

        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(catalog),
                artistPayoutAddress: address(catalog),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        vm.stopPrank();

        assertEq(cosignContract.tokenInfo(returnTokenId).artist, address(catalog));
        assertEq(cosignContract.getTokenId(catalogContractAddress, 562), returnTokenId);
    }

    function test_PurchaseTokenBasic() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(signer),
                artistPayoutAddress: address(signer),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        vm.stopPrank();

        vm.startPrank(actor);
        vm.deal(actor, 1 ether);

        cosignContract.purchaseToken{value: 0.001 ether}(returnTokenId, 1, address(0), address(0));

        vm.stopPrank();

        assertEq(cosignContract.platformFee(), 15);
        assertEq(cosignContract.artistFee(), 85);
        assertEq(cosignContract.balanceOf(address(actor), returnTokenId), 1);
        assertEq(address(cosignContract).balance, 0 ether);
        assertEq(address(signer).balance, (0.001 ether * 85) / 100);
        assertEq(address(cosignContract.platformFeeRecipient()).balance, (0.001 ether * 15) / 100);
    }

    function test_PurchaseTokenWithRecipientBasic() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(signer),
                artistPayoutAddress: address(signer),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        vm.stopPrank();

        vm.startPrank(actor);
        vm.deal(actor, 1 ether);

        cosignContract.purchaseTokenForRecipient{value: 0.001 ether}(returnTokenId, 1, dogalog, address(0), address(0));

        vm.stopPrank();

        assertEq(cosignContract.platformFee(), 15);
        assertEq(cosignContract.artistFee(), 85);
        assertEq(cosignContract.balanceOf(address(dogalog), returnTokenId), 1);
        assertEq(cosignContract.balanceOf(address(actor), returnTokenId), 0);
        assertEq(address(cosignContract).balance, 0 ether);
        assertEq(address(signer).balance, (0.001 ether * 85) / 100);
        assertEq(address(cosignContract.platformFeeRecipient()).balance, (0.001 ether * 15) / 100);
    }

    function test_RevertPurchaseTokenWithRecipientBasicZeroAddress() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(signer),
                artistPayoutAddress: address(signer),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        vm.stopPrank();

        vm.startPrank(actor);
        vm.deal(actor, 1 ether);
        vm.expectRevert(ICosignTypes.InvalidAddress.selector);

        cosignContract.purchaseTokenForRecipient{value: 0.001 ether}(
            returnTokenId, 1, address(0), address(0), address(0)
        );

        vm.stopPrank();

        // assertEq(cosignContract.platformFee(), 15);
        // assertEq(cosignContract.artistFee(), 85);
        // assertEq(cosignContract.balanceOf(address(dogalog), returnTokenId), 1);
        // assertEq(cosignContract.balanceOf(address(actor), returnTokenId), 0);
        // assertEq(address(cosignContract).balance, 0 ether);
        // assertEq(address(signer).balance, (0.001 ether * 85) / 100);
        // assertEq(address(cosignContract.platformFeeRecipient()).balance, (0.001 ether * 15) / 100);
    }

    function test_CreateTokenSetReferrralReward() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(signer),
                artistPayoutAddress: address(signer),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        cosignContract.setReferralReward(returnTokenId, 5);
        vm.stopPrank();

        assertEq(cosignContract.referralRewards(returnTokenId), 5);
    }

    function test_PurchaseTokenDualRef() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(dogalog),
                artistPayoutAddress: address(dogalog),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        cosignContract.setReferralReward(returnTokenId, 5);
        vm.stopPrank();

        vm.startPrank(actor);
        vm.deal(actor, 1 ether);

        cosignContract.purchaseToken{value: 0.001 ether}(returnTokenId, 1, address(signer), address(person));
        vm.stopPrank();

        assertEq(cosignContract.balanceOf(address(actor), returnTokenId), 1);
        assertEq(address(cosignContract).balance, 0 ether);
        assertEq(address(dogalog).balance, (0.001 ether * 80) / 100);
        assertEq(address(person).balance, (0.001 ether * 5 / 2) / 100);
        assertEq(address(signer).balance, (0.001 ether * 5 / 2) / 100);
        assertEq(address(cosignContract.platformFeeRecipient()).balance, (0.001 ether * 15) / 100);
    }

    function test_PurchaseTokenWithRecipientDualRef() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(dogalog),
                artistPayoutAddress: address(dogalog),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        cosignContract.setReferralReward(returnTokenId, 5);
        vm.stopPrank();

        vm.startPrank(actor);
        vm.deal(actor, 1 ether);

        cosignContract.purchaseTokenForRecipient{value: 0.001 ether}(
            returnTokenId, 1, address(receiver), address(signer), address(person)
        );
        vm.stopPrank();

        assertEq(cosignContract.balanceOf(address(actor), returnTokenId), 0);
        assertEq(cosignContract.balanceOf(address(receiver), returnTokenId), 1);
        assertEq(address(cosignContract).balance, 0 ether);
        assertEq(address(dogalog).balance, (0.001 ether * 80) / 100);
        assertEq(address(person).balance, (0.001 ether * 5 / 2) / 100);
        assertEq(address(signer).balance, (0.001 ether * 5 / 2) / 100);
        assertEq(address(cosignContract.platformFeeRecipient()).balance, (0.001 ether * 15) / 100);
    }

    function test_BatchPurchaseToken() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(dogalog),
                artistPayoutAddress: address(dogalog),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        cosignContract.setReferralReward(returnTokenId, 5);
        vm.stopPrank();

        vm.startPrank(actor);
        vm.deal(actor, 1 ether);

        address shiba = makeAddr("shiba");

        cosignContract.purchaseToken{value: 0.001 ether * 10}(returnTokenId, 10, shiba, address(0));
        vm.stopPrank();

        assertEq(cosignContract.balanceOf(address(actor), returnTokenId), 10);
        assertEq(address(cosignContract).balance, 0 ether);
        assertEq(address(dogalog).balance, ((0.001 ether * 10) * 80) / 100);
        assertEq(address(shiba).balance, ((0.001 ether * 10) * 5) / 100);

        assertEq(address(cosignContract.platformFeeRecipient()).balance, ((0.001 ether * 10) * 15) / 100);
    }

    function test_BatchPurchaseTokeWithRecipient() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(dogalog),
                artistPayoutAddress: address(dogalog),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        cosignContract.setReferralReward(returnTokenId, 5);
        vm.stopPrank();

        vm.startPrank(actor);
        vm.deal(actor, 1 ether);

        address shiba = makeAddr("shiba");

        cosignContract.purchaseTokenForRecipient{value: 0.001 ether * 10}(
            returnTokenId, 10, address(receiver), shiba, address(0)
        );
        vm.stopPrank();

        assertEq(cosignContract.balanceOf(address(receiver), returnTokenId), 10);
        assertEq(cosignContract.balanceOf(address(actor), returnTokenId), 0);
        assertEq(address(cosignContract).balance, 0 ether);
        assertEq(address(dogalog).balance, ((0.001 ether * 10) * 80) / 100);
        assertEq(address(shiba).balance, ((0.001 ether * 10) * 5) / 100);

        assertEq(address(cosignContract.platformFeeRecipient()).balance, ((0.001 ether * 10) * 15) / 100);
    }

    function test_BatchPurchaseTokenDualRef() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(dogalog),
                artistPayoutAddress: address(dogalog),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        cosignContract.setReferralReward(returnTokenId, 5);
        vm.stopPrank();

        vm.startPrank(actor);
        vm.deal(actor, 1 ether);

        address shiba = makeAddr("shiba");
        address akita = makeAddr("akita");

        cosignContract.purchaseToken{value: 0.001 ether * 10}(returnTokenId, 10, shiba, akita);
        vm.stopPrank();

        assertEq(cosignContract.balanceOf(address(actor), returnTokenId), 10);
        assertEq(address(cosignContract).balance, 0 ether);
        assertEq(address(dogalog).balance, ((0.001 ether * 10) * 80) / 100);
        assertEq(address(shiba).balance, ((0.001 ether * 10) * 5 / 2) / 100);
        assertEq(address(akita).balance, ((0.001 ether * 10) * 5 / 2) / 100);
        assertEq(address(cosignContract.platformFeeRecipient()).balance, ((0.001 ether * 10) * 15) / 100);
    }

    function test_BatchPurchaseTokenDualRefWithRecipient() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(dogalog),
                artistPayoutAddress: address(dogalog),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        cosignContract.setReferralReward(returnTokenId, 5);
        vm.stopPrank();

        vm.startPrank(actor);
        vm.deal(actor, 1 ether);

        address shiba = makeAddr("shiba");
        address akita = makeAddr("akita");

        cosignContract.purchaseTokenForRecipient{value: 0.001 ether * 10}(returnTokenId, 10, receiver, shiba, akita);
        vm.stopPrank();

        assertEq(cosignContract.balanceOf(address(receiver), returnTokenId), 10);
        assertEq(cosignContract.balanceOf(address(actor), returnTokenId), 0);
        assertEq(address(cosignContract).balance, 0 ether);
        assertEq(address(dogalog).balance, ((0.001 ether * 10) * 80) / 100);
        assertEq(address(shiba).balance, ((0.001 ether * 10) * 5 / 2) / 100);
        assertEq(address(akita).balance, ((0.001 ether * 10) * 5 / 2) / 100);
        assertEq(address(cosignContract.platformFeeRecipient()).balance, ((0.001 ether * 10) * 15) / 100);
    }

    function test_FuzzBatchPurchaseTokenDualRef(uint256 tokenAmount) public {
        vm.assume(tokenAmount > 1 && tokenAmount <= 999999999);
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(dogalog),
                artistPayoutAddress: address(dogalog),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        cosignContract.setReferralReward(returnTokenId, 5);
        vm.stopPrank();

        vm.startPrank(actor);
        vm.deal(actor, 1 ether * (tokenAmount / 2));

        address shiba = makeAddr("shiba");
        address akita = makeAddr("akita");

        cosignContract.purchaseToken{value: 0.001 ether * tokenAmount}(returnTokenId, tokenAmount, shiba, akita);
        vm.stopPrank();

        assertEq(cosignContract.balanceOf(address(actor), returnTokenId), tokenAmount);
        assertEq(address(cosignContract).balance, 0 ether);
        assertEq(address(dogalog).balance, ((0.001 ether * tokenAmount) * 80) / 100);
        assertEq(address(shiba).balance, ((0.001 ether * tokenAmount) * 5 / 2) / 100);
        assertEq(address(akita).balance, ((0.001 ether * tokenAmount) * 5 / 2) / 100);
        assertEq(address(cosignContract.platformFeeRecipient()).balance, ((0.001 ether * tokenAmount) * 15) / 100);
    }

    function test_FuzzBatchPurchaseTokenDualRefWithRecipient(uint256 tokenAmount) public {
        vm.assume(tokenAmount > 1 && tokenAmount <= 999999999);
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(dogalog),
                artistPayoutAddress: address(dogalog),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        cosignContract.setReferralReward(returnTokenId, 5);
        vm.stopPrank();

        vm.startPrank(actor);
        vm.deal(actor, 1 ether * (tokenAmount / 2));

        address shiba = makeAddr("shiba");
        address akita = makeAddr("akita");

        cosignContract.purchaseTokenForRecipient{value: 0.001 ether * tokenAmount}(
            returnTokenId, tokenAmount, receiver, shiba, akita
        );
        vm.stopPrank();

        assertEq(cosignContract.balanceOf(address(receiver), returnTokenId), tokenAmount);
        assertEq(cosignContract.balanceOf(address(actor), returnTokenId), 0);
        assertEq(address(cosignContract).balance, 0 ether);
        assertEq(address(dogalog).balance, ((0.001 ether * tokenAmount) * 80) / 100);
        assertEq(address(shiba).balance, ((0.001 ether * tokenAmount) * 5 / 2) / 100);
        assertEq(address(akita).balance, ((0.001 ether * tokenAmount) * 5 / 2) / 100);
        assertEq(address(cosignContract.platformFeeRecipient()).balance, ((0.001 ether * tokenAmount) * 15) / 100);
    }

    function test_MulticallBatchSetup10Token() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        bytes[] memory calls = new bytes[](10);

        for (uint256 i = 0; i < 10; ++i) {
            calls[i] = abi.encodeWithSelector(
                cosignContract.setupToken.selector,
                ICosignTypes.InputTokenData({
                    artist: address(dogalog),
                    artistPayoutAddress: address(dogalog),
                    L1ContractAddress: catalogContractAddress,
                    contentHash: "content hash",
                    L1TokenId: i + 1,
                    uri: "ar://7WeluNMLO6Fi2TfPA_HCvdLee33-lqZgx81Ni7W6_Qc"
                }),
                0
            );
        }

        bytes[] memory returnData = cosignContract.multicall(calls);

        vm.stopPrank();
    }

    function test_BatchSetup3Token() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        bytes[] memory calls = new bytes[](3);

        for (uint256 i = 0; i < 3; ++i) {
            calls[i] = abi.encodeWithSelector(
                cosignContract.setupToken.selector,
                ICosignTypes.InputTokenData({
                    artist: address(dogalog),
                    artistPayoutAddress: address(dogalog),
                    L1ContractAddress: catalogContractAddress,
                    contentHash: "content hash",
                    L1TokenId: i + 1,
                    uri: "ar://7WeluNMLO6Fi2TfPA_HCvdLee33-lqZgx81Ni7W6_Qc"
                }),
                0
            );
        }

        bytes[] memory returnData = cosignContract.multicall(calls);

        vm.stopPrank();
    }

    function test_FuzzBatchSetupTokens(uint256 tokenCount) public {
        vm.assume(tokenCount > 10 && tokenCount <= 2500);
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        bytes[] memory calls = new bytes[](tokenCount);

        for (uint256 i = 0; i < tokenCount; ++i) {
            calls[i] = abi.encodeWithSelector(
                cosignContract.setupToken.selector,
                ICosignTypes.InputTokenData({
                    artist: address(dogalog),
                    artistPayoutAddress: address(dogalog),
                    L1ContractAddress: catalogContractAddress,
                    contentHash: "content hash",
                    L1TokenId: i + 1,
                    uri: "ar://7WeluNMLO6Fi2TfPA_HCvdLee33-lqZgx81Ni7W6_Qc"
                }),
                0
            );
        }

        bytes[] memory returnData = cosignContract.multicall(calls);

        vm.stopPrank();
    }

    function test_MintTokenAdmin() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));

        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(dogalog),
                artistPayoutAddress: address(dogalog),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );
        vm.stopPrank();

        console2.log(cosignContract.tokenInfo(returnTokenId).artist);

        vm.startPrank(dogalog);

        cosignContract.mintTokenAdmin(address(dogalog), returnTokenId, 1, "");
        vm.stopPrank();

        assertEq(cosignContract.balanceOf(address(dogalog), returnTokenId), 1);
    }

    function test_RevertMintTokenAdmin() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));

        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(dogalog),
                artistPayoutAddress: address(dogalog),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );
        vm.stopPrank();

        vm.startPrank(actor);
        vm.expectRevert(ICosignTypes.Unauthorized.selector);
        cosignContract.mintTokenAdmin(address(actor), returnTokenId, 1, "");
    }

    function test_RevertMintTokenAdminBaseId() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));

        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(dogalog),
                artistPayoutAddress: address(dogalog),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        vm.expectRevert(ICosignTypes.InvalidTokenId.selector);
        cosignContract.mintTokenAdmin(address(dogalog), 0, 1, "");
    }

    function test_RevertInvalidPrice() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));

        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(dogalog),
                artistPayoutAddress: address(dogalog),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        vm.stopPrank();

        vm.startPrank(actor);
        vm.deal(actor, 1 ether);

        console2.log("TOKEN PRICE:", cosignContract.tokenPrice());

        vm.expectRevert(ICosignTypes.IncorrectValue.selector);
        cosignContract.purchaseToken{value: 0.0 ether}(returnTokenId, 1, address(0), address(0));
    }

    function test_RevertInvalidInit() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        vm.expectRevert(0xf92ee8a9);
        cosignContract.initialize(
            ICosignTypes.CosignInitData({
                _owner: address(catalog),
                _artistShare: 85,
                _platformShare: 15,
                _name: "name",
                _contractMetadataURI: ""
            })
        );
    }

    function test_RevertInvalidTokenPurchaseBasic() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(signer),
                artistPayoutAddress: address(signer),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        vm.stopPrank();

        vm.startPrank(actor);
        vm.deal(actor, 1 ether);

        vm.expectRevert(ICosignTypes.InvalidTokenId.selector);
        cosignContract.purchaseToken{value: 0.001 ether}(420, 1, address(0), address(0));
    }

    function test_RevertInvalidTokenPurchaseBasicWithRecipient() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(signer),
                artistPayoutAddress: address(signer),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        vm.stopPrank();

        vm.startPrank(actor);
        vm.deal(actor, 1 ether);

        vm.expectRevert(ICosignTypes.InvalidTokenId.selector);
        cosignContract.purchaseTokenForRecipient{value: 0.001 ether}(420, 1, receiver, address(0), address(0));
    }

    function test_RevertInvalidBaseTokenIdPurchaseBasic() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(signer),
                artistPayoutAddress: address(signer),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        vm.stopPrank();

        vm.startPrank(actor);
        vm.deal(actor, 1 ether);

        vm.expectRevert(ICosignTypes.InvalidTokenId.selector);
        cosignContract.purchaseToken{value: 0.001 ether}(0, 1, address(0), address(0));
    }

    function test_RevertInvalidBaseTokenIdPurchaseBasicWithRecipient() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(signer),
                artistPayoutAddress: address(signer),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        vm.stopPrank();

        vm.startPrank(actor);
        vm.deal(actor, 1 ether);

        vm.expectRevert(ICosignTypes.InvalidTokenId.selector);
        cosignContract.purchaseTokenForRecipient{value: 0.001 ether}(0, 1, receiver, address(0), address(0));
    }

    function test_FuzzRevertInvalidReferralReward(uint256 _rewardBPS) public {
        vm.assume(_rewardBPS > 85);
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));

        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(signer),
                artistPayoutAddress: address(signer),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        vm.stopPrank();

        vm.startPrank(signer);

        vm.expectRevert(ICosignTypes.InvalidRewardPercentage.selector);
        cosignContract.setReferralReward(returnTokenId, _rewardBPS);
    }

    function test_UpdateArtistPayoutAddress() public {
        vm.startPrank(catalog);

        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));

        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(signer),
                artistPayoutAddress: address(signer),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        vm.stopPrank();

        vm.startPrank(signer);
        cosignContract.updateTokenArtistPayoutAddress(returnTokenId, address(actor));
        vm.stopPrank();

        assertEq(cosignContract.tokenInfo(returnTokenId).artistPayoutAddress, address(actor));
    }

    function test_RevertUpdateArtistPayoutAddressInvalidTokenId() public {
        vm.startPrank(catalog);

        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));

        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(signer),
                artistPayoutAddress: address(signer),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        vm.expectRevert(ICosignTypes.InvalidTokenId.selector);
        cosignContract.updateTokenArtistPayoutAddress(0, address(actor));
        vm.stopPrank();
    }

    function test_RevertUpdateArtistPayoutAddressInvalidAddress() public {
        vm.startPrank(catalog);

        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));

        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(signer),
                artistPayoutAddress: address(signer),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        vm.startPrank(signer);

        vm.expectRevert(ICosignTypes.InvalidAddress.selector);
        cosignContract.updateTokenArtistPayoutAddress(returnTokenId, address(0));
        vm.stopPrank();
    }

    function test_RevertBurnToken() public {
        vm.startPrank(catalog);

        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(signer),
                artistPayoutAddress: address(signer),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        vm.stopPrank();
        vm.deal(signer, 500 ether);

        vm.startPrank(signer);
        cosignContract.purchaseToken{value: 0.001 ether}(returnTokenId, 1, address(0), address(0));

        assertEq(cosignContract.balanceOf(address(signer), returnTokenId), 1);

        vm.expectRevert(ICosignTypes.TransfersNotAllowed.selector);
        cosignContract.safeTransferFrom(address(signer), address(0), returnTokenId, 1, "");

        vm.expectRevert(ICosignTypes.TransfersNotAllowed.selector);
        cosignContract.safeBatchTransferFrom(address(signer), address(0), new uint256[](1), new uint256[](1), "");
    }

    function test_MaxUINT256TokenId(uint256 _tokenId) public {
        vm.assume(_tokenId > 0 && _tokenId < (1 << 96));
        vm.startPrank(catalog);

        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));

        uint256 inputMaxTokenId = _tokenId;

        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(signer),
                artistPayoutAddress: address(signer),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: inputMaxTokenId,
                uri: "uri"
            }),
            0
        );

        vm.stopPrank();

        assertEq(returnTokenId, cosignContract.getTokenId(catalogContractAddress, inputMaxTokenId));
    }

    function test_RevertMaxUINT256TokenId() public {
        vm.startPrank(catalog);

        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));

        uint256 inputMaxTokenId = type(uint256).max;

        vm.expectRevert(ICosignTypes.TokenIdOverflow.selector);
        cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(signer),
                artistPayoutAddress: address(signer),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: inputMaxTokenId,
                uri: "uri"
            }),
            0
        );
    }

    function test_PurchaseTokenBasicWithTransferRejector() public {
        vm.startPrank(catalog);

        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));

        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(signer),
                artistPayoutAddress: address(signer),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            5
        );

        vm.stopPrank();

        vm.startPrank(person);
        vm.deal(person, 1 ether);

        vm.expectRevert(
            abi.encodeWithSelector(
                ICosignTypes.PaymentFailed.selector, address(mockTransferRejector), (0.001 ether * 5) / 100
            )
        );
        cosignContract.purchaseToken{value: 0.001 ether}(returnTokenId, 1, address(mockTransferRejector), address(0));

        vm.stopPrank();

        assertEq(person.balance, 1 ether);
        assertEq(address(cosignContract).balance, 0 ether);
    }

    function test_PurchaseTokenBasicWithTransferRejectorWithRecipient() public {
        vm.startPrank(catalog);

        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));

        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(signer),
                artistPayoutAddress: address(signer),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            5
        );

        vm.stopPrank();

        vm.startPrank(person);
        vm.deal(person, 1 ether);

        vm.expectRevert(
            abi.encodeWithSelector(
                ICosignTypes.PaymentFailed.selector, address(mockTransferRejector), (0.001 ether * 5) / 100
            )
        );
        cosignContract.purchaseTokenForRecipient{value: 0.001 ether}(
            returnTokenId, 1, receiver, address(mockTransferRejector), address(0)
        );

        vm.stopPrank();

        assertEq(person.balance, 1 ether);
        assertEq(address(cosignContract).balance, 0 ether);
    }

    /// @notice use OP fork
    function test_PurchaseTokenBasicWithOPSafe() public {
        vm.startPrank(catalog);

        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));

        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(signer),
                artistPayoutAddress: address(signer),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            5
        );

        vm.stopPrank();

        vm.startPrank(person);
        vm.deal(person, 1 ether);

        cosignContract.purchaseToken{value: 0.001 ether}(returnTokenId, 1, address(catalogOPSafeAddress), address(0));

        vm.stopPrank();

        assertEq(address(signer).balance, 0.001 ether * 80 / 100);
        assertEq(address(catalogOPSafeAddress).balance, 0.001 ether * 5 / 100);
        assertEq(address(cosignContract.platformFeeRecipient()).balance, 0.001 ether * 15 / 100);
        assertEq(address(cosignContract).balance, 0 ether);
    }

    function test_PurchaseTokenBasicWithOPSafeWithRecipient() public {
        vm.startPrank(catalog);

        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));

        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(signer),
                artistPayoutAddress: address(signer),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            5
        );

        vm.stopPrank();

        vm.startPrank(person);
        vm.deal(person, 1 ether);

        cosignContract.purchaseTokenForRecipient{value: 0.001 ether}(
            returnTokenId, 1, receiver, address(catalogOPSafeAddress), address(0)
        );

        vm.stopPrank();

        assertEq(address(signer).balance, 0.001 ether * 80 / 100);
        assertEq(address(catalogOPSafeAddress).balance, 0.001 ether * 5 / 100);
        assertEq(address(cosignContract.platformFeeRecipient()).balance, 0.001 ether * 15 / 100);
        assertEq(address(cosignContract).balance, 0 ether);
    }

    function test_PurchaseTokenDualRefOPSafe() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(dogalog),
                artistPayoutAddress: address(dogalog),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        cosignContract.setReferralReward(returnTokenId, 5);
        vm.stopPrank();

        vm.startPrank(actor);
        vm.deal(actor, 1 ether);

        cosignContract.purchaseToken{value: 0.001 ether}(
            returnTokenId, 1, address(catalogOPSafeAddress), address(person)
        );
        vm.stopPrank();

        assertEq(cosignContract.balanceOf(address(actor), returnTokenId), 1);
        assertEq(address(cosignContract).balance, 0 ether);
        assertEq(address(dogalog).balance, (0.001 ether * 80) / 100);
        assertEq(address(person).balance, (0.001 ether * 5 / 2) / 100);
        assertEq(address(catalogOPSafeAddress).balance, (0.001 ether * 5 / 2) / 100);
        assertEq(address(cosignContract.platformFeeRecipient()).balance, (0.001 ether * 15) / 100);
    }

    function test_PurchaseTokenDualRefOPSafeWithRecipient() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(dogalog),
                artistPayoutAddress: address(dogalog),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        cosignContract.setReferralReward(returnTokenId, 5);
        vm.stopPrank();

        vm.startPrank(actor);
        vm.deal(actor, 1 ether);

        cosignContract.purchaseTokenForRecipient{value: 0.001 ether}(
            returnTokenId, 1, receiver, address(catalogOPSafeAddress), address(person)
        );
        vm.stopPrank();

        assertEq(cosignContract.balanceOf(address(receiver), returnTokenId), 1);
        assertEq(cosignContract.balanceOf(address(actor), returnTokenId), 0);
        assertEq(address(cosignContract).balance, 0 ether);
        assertEq(address(dogalog).balance, (0.001 ether * 80) / 100);
        assertEq(address(person).balance, (0.001 ether * 5 / 2) / 100);
        assertEq(address(catalogOPSafeAddress).balance, (0.001 ether * 5 / 2) / 100);
        assertEq(address(cosignContract.platformFeeRecipient()).balance, (0.001 ether * 15) / 100);
    }

    function test_RevertPurchaseTokenDualRefBaseTokenId() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(dogalog),
                artistPayoutAddress: address(dogalog),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        cosignContract.setReferralReward(returnTokenId, 5);
        vm.stopPrank();

        vm.startPrank(actor);
        vm.deal(actor, 1 ether);

        vm.expectRevert(ICosignTypes.InvalidTokenId.selector);
        cosignContract.purchaseToken{value: 0.001 ether}(0, 1, address(catalogOPSafeAddress), address(person));
        vm.stopPrank();
    }

    function test_RevertPurchaseTokenDualRefBaseTokenIdWithRecipient() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(dogalog),
                artistPayoutAddress: address(dogalog),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        cosignContract.setReferralReward(returnTokenId, 5);
        vm.stopPrank();

        vm.startPrank(actor);
        vm.deal(actor, 1 ether);

        vm.expectRevert(ICosignTypes.InvalidTokenId.selector);
        cosignContract.purchaseTokenForRecipient{value: 0.001 ether}(
            0, 1, receiver, address(catalogOPSafeAddress), address(person)
        );
        vm.stopPrank();
    }

    function test_RevertPurchaseTokenDualRefIncorrectValue() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(dogalog),
                artistPayoutAddress: address(dogalog),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        cosignContract.setReferralReward(returnTokenId, 5);
        vm.stopPrank();

        vm.startPrank(actor);
        vm.deal(actor, 1 ether);

        vm.expectRevert(ICosignTypes.IncorrectValue.selector);
        cosignContract.purchaseToken{value: 0.0001 ether}(
            returnTokenId, 1, address(catalogOPSafeAddress), address(person)
        );
        vm.stopPrank();
    }

    function test_RevertPurchaseTokenDualRefIncorrectValueWithRecipient() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(dogalog),
                artistPayoutAddress: address(dogalog),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        cosignContract.setReferralReward(returnTokenId, 5);
        vm.stopPrank();

        vm.startPrank(actor);
        vm.deal(actor, 1 ether);

        vm.expectRevert(ICosignTypes.IncorrectValue.selector);
        cosignContract.purchaseTokenForRecipient{value: 0.0001 ether}(
            returnTokenId, 1, receiver, address(catalogOPSafeAddress), address(person)
        );
        vm.stopPrank();
    }

    function test_RevertBatchPurchaseTokenBaseTokenId() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(dogalog),
                artistPayoutAddress: address(dogalog),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        cosignContract.setReferralReward(returnTokenId, 5);
        vm.stopPrank();

        vm.startPrank(actor);
        vm.deal(actor, 1 ether);

        vm.expectRevert(ICosignTypes.InvalidTokenId.selector);
        cosignContract.purchaseToken{value: 0.001 ether}(0, 1, address(catalogOPSafeAddress), address(0));
        vm.stopPrank();
    }

    function test_RevertBatchPurchaseTokenBaseTokenIdWithRecipient() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(dogalog),
                artistPayoutAddress: address(dogalog),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        cosignContract.setReferralReward(returnTokenId, 5);
        vm.stopPrank();

        vm.startPrank(actor);
        vm.deal(actor, 1 ether);

        vm.expectRevert(ICosignTypes.InvalidTokenId.selector);
        cosignContract.purchaseTokenForRecipient{value: 0.001 ether}(
            0, 1, receiver, address(catalogOPSafeAddress), address(0)
        );
        vm.stopPrank();
    }

    function test_RevertBatchPurchaseTokenDualRefBaseTokenId() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(dogalog),
                artistPayoutAddress: address(dogalog),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        cosignContract.setReferralReward(returnTokenId, 5);
        vm.stopPrank();

        vm.startPrank(actor);
        vm.deal(actor, 1 ether);

        vm.expectRevert(ICosignTypes.InvalidTokenId.selector);
        cosignContract.purchaseToken{value: 0.001 ether}(0, 3, address(catalogOPSafeAddress), address(person));
        vm.stopPrank();
    }

    function test_RevertBatchPurchaseTokenDualRefBaseTokenIdWithRecipient() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(dogalog),
                artistPayoutAddress: address(dogalog),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        cosignContract.setReferralReward(returnTokenId, 5);
        vm.stopPrank();

        vm.startPrank(actor);
        vm.deal(actor, 1 ether);

        vm.expectRevert(ICosignTypes.InvalidTokenId.selector);
        cosignContract.purchaseTokenForRecipient{value: 0.001 ether}(
            0, 3, receiver, address(catalogOPSafeAddress), address(person)
        );
        vm.stopPrank();
    }

    function test_RevertBatchPurchaseTokenDualRefIncorrectValue() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(dogalog),
                artistPayoutAddress: address(dogalog),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        cosignContract.setReferralReward(returnTokenId, 5);
        vm.stopPrank();

        vm.startPrank(actor);
        vm.deal(actor, 1 ether);

        vm.expectRevert(ICosignTypes.IncorrectValue.selector);
        cosignContract.purchaseToken{value: 0.001 ether}(
            returnTokenId, 3, address(catalogOPSafeAddress), address(person)
        );
        vm.stopPrank();
    }

    function test_RevertBatchPurchaseTokenDualRefIncorrectValueWithRecipient() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(dogalog),
                artistPayoutAddress: address(dogalog),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        cosignContract.setReferralReward(returnTokenId, 5);
        vm.stopPrank();

        vm.startPrank(actor);
        vm.deal(actor, 1 ether);

        vm.expectRevert(ICosignTypes.IncorrectValue.selector);
        cosignContract.purchaseTokenForRecipient{value: 0.001 ether}(
            returnTokenId, 3, receiver, address(catalogOPSafeAddress), address(person)
        );
        vm.stopPrank();
    }

    function test_RevertBatchPurchaseTokenIncorrectValue() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(dogalog),
                artistPayoutAddress: address(dogalog),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        cosignContract.setReferralReward(returnTokenId, 5);
        vm.stopPrank();

        vm.startPrank(actor);
        vm.deal(actor, 1 ether);

        vm.expectRevert(ICosignTypes.IncorrectValue.selector);
        cosignContract.purchaseToken{value: 0.001 ether}(returnTokenId, 2, address(catalogOPSafeAddress), address(0));
        vm.stopPrank();
    }

    function test_RevertBatchPurchaseTokenIncorrectValueWithRecipient() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(dogalog),
                artistPayoutAddress: address(dogalog),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        cosignContract.setReferralReward(returnTokenId, 5);
        vm.stopPrank();

        vm.startPrank(actor);
        vm.deal(actor, 1 ether);

        vm.expectRevert(ICosignTypes.IncorrectValue.selector);
        cosignContract.purchaseTokenForRecipient{value: 0.001 ether}(
            returnTokenId, 2, receiver, address(catalogOPSafeAddress), address(0)
        );
        vm.stopPrank();
    }

    function test_PurchaseTokenDualRefDualOPSafe() public {
        address OP_SAFE_RANDOM_1 = 0xE562000f90b2643d21080E83C32D4c16913934E1;
        address OP_SAFE_RANDOM_2 = 0x6760c778b6d237A331b104ce2565C1E1A1948436;

        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(dogalog),
                artistPayoutAddress: address(dogalog),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        cosignContract.setReferralReward(returnTokenId, 5);
        vm.stopPrank();

        vm.startPrank(actor);
        vm.deal(actor, 1 ether);

        cosignContract.purchaseToken{value: 0.001 ether}(
            returnTokenId, 1, address(catalogOPSafeAddress), address(OP_SAFE_RANDOM_1)
        );
        vm.stopPrank();

        assertEq(cosignContract.balanceOf(address(actor), returnTokenId), 1);
        assertEq(address(cosignContract).balance, 0 ether);
        assertEq(address(dogalog).balance, (0.001 ether * 80) / 100);
        assertEq(address(OP_SAFE_RANDOM_1).balance, (0.001 ether * 5 / 2) / 100);
        assertEq(address(catalogOPSafeAddress).balance, (0.001 ether * 5 / 2) / 100);
        assertEq(address(cosignContract.platformFeeRecipient()).balance, (0.001 ether * 15) / 100);
    }

    function test_PurchaseTokenDualRefDualOPSafeWithRecipient() public {
        address OP_SAFE_RANDOM_1 = 0xE562000f90b2643d21080E83C32D4c16913934E1;
        address OP_SAFE_RANDOM_2 = 0x6760c778b6d237A331b104ce2565C1E1A1948436;

        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(dogalog),
                artistPayoutAddress: address(dogalog),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        cosignContract.setReferralReward(returnTokenId, 5);
        vm.stopPrank();

        vm.startPrank(actor);
        vm.deal(actor, 1 ether);

        cosignContract.purchaseTokenForRecipient{value: 0.001 ether}(
            returnTokenId, 1, receiver, address(catalogOPSafeAddress), address(OP_SAFE_RANDOM_1)
        );
        vm.stopPrank();

        assertEq(cosignContract.balanceOf(address(receiver), returnTokenId), 1);
        assertEq(cosignContract.balanceOf(address(actor), returnTokenId), 0);
        assertEq(address(cosignContract).balance, 0 ether);
        assertEq(address(dogalog).balance, (0.001 ether * 80) / 100);
        assertEq(address(OP_SAFE_RANDOM_1).balance, (0.001 ether * 5 / 2) / 100);
        assertEq(address(catalogOPSafeAddress).balance, (0.001 ether * 5 / 2) / 100);
        assertEq(address(cosignContract.platformFeeRecipient()).balance, (0.001 ether * 15) / 100);
    }

    function test_PurchaseTokenDualRefDualOPSafePrototype() public {
        address OP_SAFE_RANDOM_1 = 0xE562000f90b2643d21080E83C32D4c16913934E1;
        address OP_SAFE_RANDOM_2 = 0x6760c778b6d237A331b104ce2565C1E1A1948436;

        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(dogalog),
                artistPayoutAddress: address(dogalog),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        cosignContract.setReferralReward(returnTokenId, 5);
        vm.stopPrank();

        vm.startPrank(actor);
        vm.deal(actor, 1 ether);

        cosignContract.purchaseToken{value: 0.001 ether}(
            returnTokenId, 1, address(catalogOPSafeAddress), address(OP_SAFE_RANDOM_1)
        );
        vm.stopPrank();

        assertEq(cosignContract.balanceOf(address(actor), returnTokenId), 1);
        assertEq(address(cosignContract).balance, 0 ether);
        assertEq(address(dogalog).balance, (0.001 ether * 80) / 100);
        assertEq(address(OP_SAFE_RANDOM_1).balance, (0.001 ether * 5 / 2) / 100);
        assertEq(address(catalogOPSafeAddress).balance, (0.001 ether * 5 / 2) / 100);
        assertEq(address(cosignContract.platformFeeRecipient()).balance, (0.001 ether * 15) / 100);
    }

    function test_PurchaseTokenDualRefDualOPSafePrototypeWithRecipient() public {
        address OP_SAFE_RANDOM_1 = 0xE562000f90b2643d21080E83C32D4c16913934E1;
        address OP_SAFE_RANDOM_2 = 0x6760c778b6d237A331b104ce2565C1E1A1948436;

        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(dogalog),
                artistPayoutAddress: address(dogalog),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        cosignContract.setReferralReward(returnTokenId, 5);
        vm.stopPrank();

        vm.startPrank(actor);
        vm.deal(actor, 1 ether);

        cosignContract.purchaseTokenForRecipient{value: 0.001 ether}(
            returnTokenId, 1, receiver, address(catalogOPSafeAddress), address(OP_SAFE_RANDOM_1)
        );
        vm.stopPrank();

        assertEq(cosignContract.balanceOf(address(receiver), returnTokenId), 1);
        assertEq(cosignContract.balanceOf(address(actor), returnTokenId), 0);
        assertEq(address(cosignContract).balance, 0 ether);
        assertEq(address(dogalog).balance, (0.001 ether * 80) / 100);
        assertEq(address(OP_SAFE_RANDOM_1).balance, (0.001 ether * 5 / 2) / 100);
        assertEq(address(catalogOPSafeAddress).balance, (0.001 ether * 5 / 2) / 100);
        assertEq(address(cosignContract.platformFeeRecipient()).balance, (0.001 ether * 15) / 100);
    }

    function test_SmallReferralReward() public {
        address OP_SAFE_RANDOM_1 = 0xE562000f90b2643d21080E83C32D4c16913934E1;
        address OP_SAFE_RANDOM_2 = 0x6760c778b6d237A331b104ce2565C1E1A1948436;

        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(dogalog),
                artistPayoutAddress: address(dogalog),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        cosignContract.setReferralReward(returnTokenId, 1);
        vm.stopPrank();

        vm.startPrank(actor);
        vm.deal(actor, 1 ether);

        cosignContract.purchaseToken{value: 0.001 ether}(
            returnTokenId, 1, address(catalogOPSafeAddress), address(OP_SAFE_RANDOM_1)
        );
        vm.stopPrank();

        assertEq(cosignContract.balanceOf(address(actor), returnTokenId), 1);
        assertEq(address(cosignContract).balance, 0 ether);
        assertEq(address(dogalog).balance, (0.001 ether * 84) / 100);
        assertEq(address(OP_SAFE_RANDOM_1).balance, (0.001 ether * 1 / 2) / 100);
        assertEq(address(catalogOPSafeAddress).balance, (0.001 ether * 1 / 2) / 100);
        assertEq(address(cosignContract.platformFeeRecipient()).balance, (0.001 ether * 15) / 100);
    }

    function test_SmallReferralRewardWithRecipient() public {
        address OP_SAFE_RANDOM_1 = 0xE562000f90b2643d21080E83C32D4c16913934E1;
        address OP_SAFE_RANDOM_2 = 0x6760c778b6d237A331b104ce2565C1E1A1948436;

        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(dogalog),
                artistPayoutAddress: address(dogalog),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        cosignContract.setReferralReward(returnTokenId, 1);
        vm.stopPrank();

        vm.startPrank(actor);
        vm.deal(actor, 1 ether);

        cosignContract.purchaseTokenForRecipient{value: 0.001 ether}(
            returnTokenId, 1, receiver, address(catalogOPSafeAddress), address(OP_SAFE_RANDOM_1)
        );
        vm.stopPrank();

        assertEq(cosignContract.balanceOf(address(receiver), returnTokenId), 1);
        assertEq(cosignContract.balanceOf(address(actor), returnTokenId), 0);
        assertEq(address(cosignContract).balance, 0 ether);
        assertEq(address(dogalog).balance, (0.001 ether * 84) / 100);
        assertEq(address(OP_SAFE_RANDOM_1).balance, (0.001 ether * 1 / 2) / 100);
        assertEq(address(catalogOPSafeAddress).balance, (0.001 ether * 1 / 2) / 100);
        assertEq(address(cosignContract.platformFeeRecipient()).balance, (0.001 ether * 15) / 100);
    }

    function test_Multicall() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeWithSelector(
            cosignContract.setupToken.selector,
            ICosignTypes.InputTokenData({
                artist: address(dogalog),
                artistPayoutAddress: address(dogalog),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "ar://7WeluNMLO6Fi2TfPA_HCvdLee33-lqZgx81Ni7W6_Qc"
            }),
            0
        );
        calls[1] = abi.encodeWithSelector(
            cosignContract.setupToken.selector,
            ICosignTypes.InputTokenData({
                artist: address(dogalog),
                artistPayoutAddress: address(dogalog),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 563,
                uri: "uri"
            }),
            0
        );
        calls[2] = abi.encodeWithSelector(
            cosignContract.setupToken.selector,
            ICosignTypes.InputTokenData({
                artist: address(actor),
                artistPayoutAddress: address(actor),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 564,
                uri: "uri"
            }),
            0
        );

        bytes[] memory returnData = cosignContract.multicall(calls);

        vm.stopPrank();

        assertEq(returnData.length, 3);
        assertEq(bytesToUint256(returnData[0]) == cosignContract.getTokenId(catalogContractAddress, 562), true);
        assertEq(cosignContract.uri(bytesToUint256(returnData[0])), "ar://7WeluNMLO6Fi2TfPA_HCvdLee33-lqZgx81Ni7W6_Qc");
    }

    function test_Token0() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));

        CatalogCosignsImplementation.TokenData memory tokenData = cosignContract.tokenInfo(0);

        assertEq(tokenData.artist, address(0));
        assertEq(tokenData.artistPayoutAddress, address(0));
        assertEq(tokenData.contentHash, bytes32(0));
        assertEq(cosignContract.uri(0), "");
    }

    function test_RevertMulticallDuplicateToken() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeWithSelector(
            cosignContract.setupToken.selector,
            ICosignTypes.InputTokenData({
                artist: address(dogalog),
                artistPayoutAddress: address(dogalog),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "ar://7WeluNMLO6Fi2TfPA_HCvdLee33-lqZgx81Ni7W6_Qc"
            }),
            0
        );
        calls[1] = abi.encodeWithSelector(
            cosignContract.setupToken.selector,
            ICosignTypes.InputTokenData({
                artist: address(dogalog),
                artistPayoutAddress: address(dogalog),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );
        calls[2] = abi.encodeWithSelector(
            cosignContract.setupToken.selector,
            ICosignTypes.InputTokenData({
                artist: address(actor),
                artistPayoutAddress: address(actor),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 564,
                uri: "uri"
            }),
            0
        );

        vm.expectRevert(ICosignTypes.TokenAlreadyExists.selector);
        bytes[] memory returnData = cosignContract.multicall(calls);

        vm.stopPrank();
    }

    function test_AdminPermission() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(dogalog),
                artistPayoutAddress: address(dogalog),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        cosignContract.setAdminPermission(address(actor), 2);
        vm.stopPrank();

        vm.startPrank(actor);
        cosignContract.setReferralReward(returnTokenId, 1);

        vm.stopPrank();

        assertEq(cosignContract.referralRewards(returnTokenId), 1);
    }

    function test_RevertAdminPermission() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(dogalog),
                artistPayoutAddress: address(dogalog),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            0
        );

        cosignContract.setAdminPermission(address(actor), 2);
        vm.stopPrank();

        vm.startPrank(actor);
        cosignContract.setReferralReward(returnTokenId, 1);
        assertEq(cosignContract.referralRewards(returnTokenId), 1);

        vm.stopPrank();

        vm.startPrank(catalog);
        cosignContract.setAdminPermission(address(actor), 0);
        assertEq(cosignContract.referralRewards(returnTokenId), 1);
        vm.stopPrank();

        cosignContract.authPermissions(address(actor));

        vm.startPrank(actor);
        vm.expectRevert(ICosignTypes.Unauthorized.selector);
        cosignContract.setReferralReward(returnTokenId, 5);
    }

    function test_SafeProtocolPayout() public {
        address OP_SAFE_RANDOM_1 = 0xE562000f90b2643d21080E83C32D4c16913934E1;
        address OP_SAFE_RANDOM_2 = 0x6760c778b6d237A331b104ce2565C1E1A1948436;
        address ZEROX_SPLIT_TEST = 0x0D1C09779f5bF99dB7A13bf87226792499554597;

        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));

        cosignContract.setPlatformFeeRecipient(catalogOPSafeAddress);
        assertEq(address(cosignContract.platformFeeRecipient()), address(catalogOPSafeAddress));

        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(actor),
                artistPayoutAddress: address(ZEROX_SPLIT_TEST),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: ""
            }),
            5
        );

        vm.stopPrank();

        vm.startPrank(person);
        vm.deal(person, 1 ether);

        cosignContract.purchaseToken{value: 0.001 ether}(
            returnTokenId, 1, address(OP_SAFE_RANDOM_1), address(OP_SAFE_RANDOM_2)
        );

        vm.stopPrank();

        assertEq(cosignContract.balanceOf(address(person), returnTokenId), 1);
        assertEq(address(cosignContract).balance, 0 ether);
        assertEq(address(ZEROX_SPLIT_TEST).balance, (0.001 ether * 80) / 100);
        assertEq(address(OP_SAFE_RANDOM_1).balance, (0.001 ether * 5 / 2) / 100);
        assertEq(address(OP_SAFE_RANDOM_2).balance, (0.001 ether * 5 / 2) / 100);
        assertEq(address(catalogOPSafeAddress).balance, (0.001 ether * 15) / 100);
    }

    function test_InvariantReferralRewardDistribution(
        uint256 tokenId,
        address buyer,
        uint256 purchaseAmount,
        address referrer
    ) internal {
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));

        uint256 referrerBalanceBefore = address(referrer).balance;
        uint256 referralReward = cosignContract.referralRewards(tokenId);

        vm.deal(buyer, purchaseAmount * 2);

        vm.startPrank(buyer);
        // Simulate purchase with referral
        cosignContract.purchaseToken{value: purchaseAmount}(tokenId, 1, referrer, address(0));
        vm.stopPrank();

        uint256 referrerBalanceAfter = address(referrer).balance;
        uint256 expectedReferralPayout = (purchaseAmount * referralReward) / 100;

        assertEq(
            referrerBalanceAfter,
            referrerBalanceBefore + expectedReferralPayout,
            "Invariant failed: Referral reward not distributed correctly"
        );
    }

    function test_InvariantAdminPermission(address subject, uint256 expectedPermissionLevel) internal {
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));

        uint256 actualPermissionLevel = cosignContract.authPermissions(subject);
        assertEq(
            actualPermissionLevel,
            expectedPermissionLevel,
            "Invariant failed: Admin permission level changed unexpectedly"
        );
    }

    function test_AdminPermittedTokenSetup() public {
        address shiba = makeAddr("shiba");
        vm.deal(shiba, 1 ether);

        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        cosignContract.setAdminPermission(shiba, 2);
        vm.stopPrank();

        assertEq(cosignContract.authPermissions(shiba), 2);

        vm.startPrank(shiba);

        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(person),
                artistPayoutAddress: address(person),
                L1ContractAddress: catalogContractAddress,
                contentHash: bytes32(0x8b27e94ac21f73d9ebe47d485561a595e4faa68bb1ec027baeaea60838a5986a),
                L1TokenId: 987,
                uri: "ar://0d_YTshj4_tdIpU_5zBBX51z0KTwhUrzrL9qs7uqcA0"
            }),
            0
        );

        vm.stopPrank();
    }

    function test_RevertTokenSetupWithInvalidPayoutOrArtist() public {
        address shiba = makeAddr("shiba");
        vm.deal(shiba, 1 ether);

        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        cosignContract.setAdminPermission(shiba, 2);
        vm.stopPrank();

        assertEq(cosignContract.authPermissions(shiba), 2);

        vm.startPrank(shiba);

        vm.expectRevert(ICosignTypes.InvalidAddress.selector);
        uint256 returnTokenId1 = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(0),
                artistPayoutAddress: address(person),
                L1ContractAddress: catalogContractAddress,
                contentHash: bytes32(0x8b27e94ac21f73d9ebe47d485561a595e4faa68bb1ec027baeaea60838a5986a),
                L1TokenId: 987,
                uri: "ar://0d_YTshj4_tdIpU_5zBBX51z0KTwhUrzrL9qs7uqcA0"
            }),
            0
        );
        vm.stopPrank();
    }

    function test_RevertTokenSetupWithInvalidRewardPercentage() public {
        address shiba = makeAddr("shiba");
        vm.deal(shiba, 1 ether);

        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        cosignContract.setAdminPermission(shiba, 2);
        vm.stopPrank();

        assertEq(cosignContract.authPermissions(shiba), 2);

        vm.startPrank(shiba);

        vm.expectRevert(ICosignTypes.InvalidRewardPercentage.selector);
        uint256 returnTokenId1 = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(person),
                artistPayoutAddress: address(person),
                L1ContractAddress: catalogContractAddress,
                contentHash: bytes32(0x8b27e94ac21f73d9ebe47d485561a595e4faa68bb1ec027baeaea60838a5986a),
                L1TokenId: 987,
                uri: "ar://0d_YTshj4_tdIpU_5zBBX51z0KTwhUrzrL9qs7uqcA0"
            }),
            86
        );
        vm.stopPrank();
    }

    function test_RevertWithInterfaceCalls() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));

        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(person),
                artistPayoutAddress: address(person),
                L1ContractAddress: catalogContractAddress,
                contentHash: bytes32(0x8b27e94ac21f73d9ebe47d485561a595e4faa68bb1ec027baeaea60838a5986a),
                L1TokenId: 987,
                uri: "ar://0d_YTshj4_tdIpU_5zBBX51z0KTwhUrzrL9qs7uqcA0"
            }),
            0
        );

        vm.stopPrank();

        vm.startPrank(person);
        vm.deal(person, 1 ether);

        cosignContract.purchaseToken{value: 0.001 ether}(returnTokenId, 1, address(0), address(0));

        assertEq(cosignContract.balanceOf(address(person), returnTokenId), 1);

        vm.expectRevert(ICosignTypes.TransfersNotAllowed.selector);
        IERC1155(address(proxyContract)).safeTransferFrom(address(person), address(0), returnTokenId, 1, "");

        vm.expectRevert(ICosignTypes.TransfersNotAllowed.selector);
        IERC1155(address(proxyContract)).safeBatchTransferFrom(
            address(person), address(0), new uint256[](1), new uint256[](1), ""
        );

        vm.expectRevert(ICosignTypes.ApprovalsNotAllowed.selector);
        IERC1155(address(proxyContract)).setApprovalForAll(address(person), true);

        vm.stopPrank();
    }

    function test_ERC165Calls() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));

        // check 1155 interface
        assertEq(cosignContract.supportsInterface(0xd9b67a26), true);
        assertEq(cosignContract.supportsInterface(0x0e89341c), true);

        vm.stopPrank();
    }

    function test_UpgradeSafetyStorage() public {
        address shiba = makeAddr("shiba");
        vm.deal(shiba, 1 ether);

        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));

        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(person),
                artistPayoutAddress: address(person),
                L1ContractAddress: catalogContractAddress,
                contentHash: bytes32(0x8b27e94ac21f73d9ebe47d485561a595e4faa68bb1ec027baeaea60838a5986a),
                L1TokenId: 987,
                uri: "ar://0d_YTshj4_tdIpU_5zBBX51z0KTwhUrzrL9qs7uqcA0"
            }),
            5
        );

        uint256 returnTokenId1 = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(person),
                artistPayoutAddress: address(person),
                L1ContractAddress: catalogContractAddress,
                contentHash: bytes32(0x8b27e94ac21f73d9ebe47d485561a595e4faa68bb1ec027baeaea60838a5986a),
                L1TokenId: 989,
                uri: "ar://0d_YTshj4_tdIpU_5zBBX51z0KTwhUrzrL9qs7uqcA0"
            }),
            0
        );

        cosignContract.setPlatformFeeRecipient(catalogOPSafeAddress);

        assertEq(cosignContract.tokenInfo(returnTokenId).artist, address(person));
        assertEq(cosignContract.tokenInfo(returnTokenId1).artistPayoutAddress, address(person));
        assertEq(
            cosignContract.tokenInfo(returnTokenId).contentHash,
            bytes32(0x8b27e94ac21f73d9ebe47d485561a595e4faa68bb1ec027baeaea60838a5986a)
        );
        assertEq(cosignContract.uri(returnTokenId1), "ar://0d_YTshj4_tdIpU_5zBBX51z0KTwhUrzrL9qs7uqcA0");

        cosignContract.setAdminPermission(shiba, 2);
        vm.stopPrank();

        assertEq(cosignContract.authPermissions(shiba), 2);
        vm.startPrank(shiba);

        CatalogCosignsImplementation newCosignContract = new CatalogCosignsImplementation();
        cosignContract.upgradeToAndCall(address(newCosignContract), "");

        assertEq(cosignContract.tokenInfo(returnTokenId).artist, address(person));
        assertEq(cosignContract.tokenInfo(returnTokenId1).artistPayoutAddress, address(person));
        assertEq(
            cosignContract.tokenInfo(returnTokenId).contentHash,
            bytes32(0x8b27e94ac21f73d9ebe47d485561a595e4faa68bb1ec027baeaea60838a5986a)
        );
        assertEq(cosignContract.uri(returnTokenId1), "ar://0d_YTshj4_tdIpU_5zBBX51z0KTwhUrzrL9qs7uqcA0");
        assertEq(cosignContract.authPermissions(shiba), 2);
        assertEq(address(cosignContract.platformFeeRecipient()), address(catalogOPSafeAddress));
        assertEq(cosignContract.tokenPrice(), 0.001 ether);
        assertEq(cosignContract.referralRewards(returnTokenId), 5);
        assertEq(cosignContract.contractName(), "name");
        vm.stopPrank();

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        cosignContract.initialize(
            ICosignTypes.CosignInitData({
                _owner: address(catalog),
                _artistShare: 85,
                _platformShare: 15,
                _name: "name-test",
                _contractMetadataURI: ""
            })
        );
    }

    function test_UpdateTokenURI() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));

        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(person),
                artistPayoutAddress: address(person),
                L1ContractAddress: catalogContractAddress,
                contentHash: bytes32(0x8b27e94ac21f73d9ebe47d485561a595e4faa68bb1ec027baeaea60838a5986a),
                L1TokenId: 987,
                uri: "ar://0d_YTshj4_tdIpU_5zBBX51z0KTwhUrzrL9qs7uqcA0"
            }),
            0
        );

        vm.stopPrank();

        string memory oldURI = cosignContract.uri(returnTokenId);

        vm.startPrank(person);

        cosignContract.updateTokenURI(returnTokenId, "new uri");

        vm.stopPrank();

        assertEq(cosignContract.uri(returnTokenId), "new uri");

        vm.startPrank(person);

        cosignContract.updateTokenURI(returnTokenId, "ar://0d_YTshj4_tdIpU_5zBBX51z0KTwhUrzrL9qs7uqcA0");

        vm.stopPrank();

        assertEq(cosignContract.uri(returnTokenId), oldURI);
    }

    function test_RevertUpdateTokenURI() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));

        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(person),
                artistPayoutAddress: address(person),
                L1ContractAddress: catalogContractAddress,
                contentHash: bytes32(0x8b27e94ac21f73d9ebe47d485561a595e4faa68bb1ec027baeaea60838a5986a),
                L1TokenId: 987,
                uri: "ar://0d_YTshj4_tdIpU_5zBBX51z0KTwhUrzrL9qs7uqcA0"
            }),
            0
        );

        vm.expectRevert(ICosignTypes.InvalidTokenId.selector);
        cosignContract.updateTokenURI(0, "new uri");

        vm.stopPrank();
    }

    function test_UpdateContractURI() public {
        vm.startPrank(catalog);
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));

        string memory oldURI = cosignContract.contractURI();

        cosignContract.updateContractURI("new uri");

        assertEq(cosignContract.contractURI(), "new uri");

        cosignContract.updateContractURI(oldURI);

        assertEq(cosignContract.contractURI(), oldURI);
    }

    function test_SetFees() public {
        vm.startPrank(catalog);
        address shiba = makeAddr("shiba");
        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));

        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(person),
                artistPayoutAddress: address(person),
                L1ContractAddress: catalogContractAddress,
                contentHash: bytes32(0x8b27e94ac21f73d9ebe47d485561a595e4faa68bb1ec027baeaea60838a5986a),
                L1TokenId: 987,
                uri: "ar://0d_YTshj4_tdIpU_5zBBX51z0KTwhUrzrL9qs7uqcA0"
            }),
            5
        );

        uint256 oldPlatformFee = cosignContract.platformFee();
        uint256 oldArtistFee = cosignContract.artistFee();

        cosignContract.setFees(10, 90);

        assertEq(cosignContract.platformFee(), 90);
        assertEq(cosignContract.artistFee(), 10);

        // ensure purchase payouts are correct

        vm.stopPrank();
        vm.startPrank(actor);
        vm.deal(actor, 1 ether);

        cosignContract.purchaseToken{value: 0.001 ether}(returnTokenId, 1, address(shiba), address(0));

        assertEq(cosignContract.balanceOf(address(actor), returnTokenId), 1);
        assertEq(address(cosignContract).balance, 0 ether);
        assertEq(address(shiba).balance, (0.001 ether * 5) / 100);
        assertEq(address(person).balance, (0.001 ether * 5) / 100);
        assertEq(address(cosignContract.platformFeeRecipient()).balance, (0.001 ether * 90) / 100);
        vm.stopPrank();

        vm.startPrank(catalog);
        cosignContract.setFees(oldArtistFee, oldPlatformFee);

        assertEq(cosignContract.platformFee(), oldPlatformFee);
        assertEq(cosignContract.artistFee(), oldArtistFee);
    }

    function test_RevertSetFees() public {
        vm.startPrank(catalog);

        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));

        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(person),
                artistPayoutAddress: address(person),
                L1ContractAddress: catalogContractAddress,
                contentHash: bytes32(0x8b27e94ac21f73d9ebe47d485561a595e4faa68bb1ec027baeaea60838a5986a),
                L1TokenId: 987,
                uri: "ar://0d_YTshj4_tdIpU_5zBBX51z0KTwhUrzrL9qs7uqcA0"
            }),
            5
        );

        uint256 oldPlatformFee = cosignContract.platformFee();
        uint256 oldArtistFee = cosignContract.artistFee();

        vm.expectRevert(ICosignTypes.InvalidFeePercentage.selector);
        cosignContract.setFees(15, 90);
    }

    function test_SetTokenPrice() public {
        vm.startPrank(catalog);
        address shiba = makeAddr("shiba");

        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));

        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(person),
                artistPayoutAddress: address(person),
                L1ContractAddress: catalogContractAddress,
                contentHash: bytes32(0x8b27e94ac21f73d9ebe47d485561a595e4faa68bb1ec027baeaea60838a5986a),
                L1TokenId: 987,
                uri: "ar://0d_YTshj4_tdIpU_5zBBX51z0KTwhUrzrL9qs7uqcA0"
            }),
            5
        );

        uint256 oldTokenPrice = cosignContract.tokenPrice();

        cosignContract.setTokenPrice(0.002 ether);

        assertEq(cosignContract.tokenPrice(), 0.002 ether);

        // ensure purchase payouts are correct

        vm.stopPrank();
        vm.startPrank(actor);
        vm.deal(actor, 1 ether);

        cosignContract.purchaseToken{value: 0.002 ether}(returnTokenId, 1, address(shiba), address(0));

        assertEq(cosignContract.balanceOf(address(actor), returnTokenId), 1);
        assertEq(address(cosignContract).balance, 0 ether);
        assertEq(address(shiba).balance, (0.002 ether * 5) / 100);
        assertEq(address(person).balance, (0.002 ether * 80) / 100);
        assertEq(address(cosignContract.platformFeeRecipient()).balance, (0.002 ether * 15) / 100);

        vm.stopPrank();
    }

    function test_TokenInfoByRecord() public {
        vm.startPrank(catalog);

        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));

        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(person),
                artistPayoutAddress: address(person),
                L1ContractAddress: catalogContractAddress,
                contentHash: bytes32(0x8b27e94ac21f73d9ebe47d485561a595e4faa68bb1ec027baeaea60838a5986a),
                L1TokenId: 987,
                uri: "ar://0d_YTshj4_tdIpU_5zBBX51z0KTwhUrzrL9qs7uqcA0"
            }),
            5
        );

        vm.stopPrank();

        CatalogCosignsImplementation.TokenData memory tokenData =
            cosignContract.tokenInfoByRecord(987, catalogContractAddress);
        string memory uri = cosignContract.uri(returnTokenId);

        assertEq(tokenData.artist, address(person));
        assertEq(tokenData.artistPayoutAddress, address(person));
        assertEq(tokenData.contentHash, bytes32(0x8b27e94ac21f73d9ebe47d485561a595e4faa68bb1ec027baeaea60838a5986a));
        assertEq(uri, "ar://0d_YTshj4_tdIpU_5zBBX51z0KTwhUrzrL9qs7uqcA0");

        (address outputContract, uint256 outputTokenid) = cosignContract.getL1Details(returnTokenId);

        assertEq(outputContract, catalogContractAddress);
        assertEq(outputTokenid, 987);
    }

    function test_ContractURI() public {
        vm.startPrank(catalog);

        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));

        string memory newURI = "ar://0d_YTshj4_tdIpU_5zBBX51z0KTwhUrzrL9qs7uqcA0";

        string memory contractURI = cosignContract.contractURI();
        assertEq(contractURI, "");

        cosignContract.updateContractURI(newURI);
        assertEq(cosignContract.contractURI(), newURI);
    }

    function test_RevertSetReferralRewardBaseId() public {
        vm.startPrank(catalog);
        address shiba = makeAddr("shiba");

        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));

        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(person),
                artistPayoutAddress: address(person),
                L1ContractAddress: catalogContractAddress,
                contentHash: bytes32(0x8b27e94ac21f73d9ebe47d485561a595e4faa68bb1ec027baeaea60838a5986a),
                L1TokenId: 987,
                uri: ""
            }),
            5
        );

        vm.expectRevert(ICosignTypes.InvalidTokenId.selector);
        cosignContract.setReferralReward(0, 5);
    }

    function test_RevertSetPlatformFeeRecipientInvalidAddress() public {
        vm.startPrank(catalog);

        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));

        vm.expectRevert(ICosignTypes.InvalidAddress.selector);
        cosignContract.setPlatformFeeRecipient(address(0));

        vm.stopPrank();
    }

    function test_Withdraw() public {
        vm.startPrank(catalog);
        address shiba = makeAddr("shiba");

        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));
        address protocolFeePayoutReceiver = CatalogCosignsImplementation(address(proxyContract)).platformFeeRecipient();

        // force a remainder
        cosignContract.setTokenPrice(0.000000000000000001 ether);
        cosignContract.setFees(90, 10);

        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(person),
                artistPayoutAddress: address(person),
                L1ContractAddress: catalogContractAddress,
                contentHash: "",
                L1TokenId: 987,
                uri: ""
            }),
            5
        );

        vm.stopPrank();

        vm.startPrank(dogalog);

        vm.deal(dogalog, 3 ether);

        cosignContract.purchaseToken{value: 0.000000000000000001 ether}(
            returnTokenId, 1, address(actor), address(shiba)
        );

        vm.stopPrank();
        uint256 tokenPrice = cosignContract.tokenPrice();

        assertEq(cosignContract.balanceOf(address(dogalog), returnTokenId), 1);
        assertEq(address(person).balance, (tokenPrice * 85) / 100);
        assertEq(address(actor).balance, (tokenPrice * 1 / 2) / 100);
        assertEq(address(shiba).balance, (tokenPrice * 1 / 2) / 100);
        assertEq(address(protocolFeePayoutReceiver).balance, (tokenPrice * 5) / 100);
        console2.log("contract balance", address(cosignContract).balance);

        assertTrue(payable(address(cosignContract)).balance > 0);

        vm.startPrank(catalog);

        uint256 prevBalanceCatalog = address(cosignContract.platformFeeRecipient()).balance;

        cosignContract.withdraw();

        assertEq(address(cosignContract).balance, 0 ether);
        assertEq(address(cosignContract.platformFeeRecipient()).balance, prevBalanceCatalog + 1 wei);

        vm.stopPrank();
    }

    function test_TransferOwnership() public {
        vm.startPrank(catalog);
        address shiba = makeAddr("shiba");

        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));

        address prevOwner = cosignContract.owner();

        cosignContract.transferOwnership(shiba);

        assertEq(cosignContract.pendingOwner(), shiba);

        vm.stopPrank();

        vm.startPrank(shiba);
        cosignContract.acceptOwnership();
        assertEq(cosignContract.owner(), shiba);
        vm.stopPrank();
    }

    function test_RejectTokenRejectorPurchase() public {
        vm.startPrank(catalog);

        CatalogCosignsImplementation cosignContract = CatalogCosignsImplementation(address(proxyContract));

        uint256 returnTokenId = cosignContract.setupToken(
            ICosignTypes.InputTokenData({
                artist: address(signer),
                artistPayoutAddress: address(signer),
                L1ContractAddress: catalogContractAddress,
                contentHash: "content hash",
                L1TokenId: 562,
                uri: "uri"
            }),
            5
        );

        vm.stopPrank();

        vm.startPrank(person);
        vm.deal(person, 1 ether);

        vm.expectRevert("ERC1155 tokens not accepted");
        cosignContract.purchaseTokenForRecipient{value: 0.001 ether}(
            returnTokenId, 1, address(mockERC1155Rejector), address(0), address(0)
        );

        vm.stopPrank();

        assertEq(person.balance, 1 ether);
        assertEq(address(cosignContract).balance, 0 ether);
        assertEq(cosignContract.balanceOf(address(person), returnTokenId), 0);
        assertEq(cosignContract.balanceOf(address(mockERC1155Rejector), returnTokenId), 0);
    }
}

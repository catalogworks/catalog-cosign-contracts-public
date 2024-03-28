// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test, console2} from "forge-std/Test.sol";
import {URILib} from "../src/shared/storage/URILib.sol";
import {MockMultiCallImplementer} from "./mocks/MockMultiCallImplementer.sol";

contract URILibTest is Test {
    using URILib for URILib.URI;

    URILib.URI private testURI;
    MockMultiCallImplementer private testMultiCallContract;

    function setUp() public {
        testMultiCallContract = new MockMultiCallImplementer();
    }

    // Test initialization with a normal URI
    function test_InitializeWithNormalURI() public {
        string memory normalURI = "https://example.com";
        testURI.initializeURI(normalURI);
        assertEq(testURI.loadURI(), normalURI);
        assertEq(bytes32(0), testURI.arweaveURI);
    }

    // Test initialization with an Arweave URI
    function test_InitializeWithArweaveURI() public {
        string memory arweaveURI = "ar://EXAMPLE_CID";
        testURI.initializeURI(arweaveURI);
        assertEq(testURI.loadURI(), arweaveURI);
    }

    // Test storing a normal URI
    function test_StoreNormalURI() public {
        string memory normalURI = "https://newexample.com";
        testURI.storeURI(normalURI, false);
        assertEq(testURI.loadURI(), normalURI);
        assertEq(bytes32(0), testURI.arweaveURI);
    }

    // Test storing an Arweave URI
    function test_StoreArweaveURI() public {
        string memory arweaveURI = "ar://NEW_EXAMPLE_CID";
        testURI.storeURI(arweaveURI, false);
        assertEq(testURI.loadURI(), arweaveURI);
    }

    // Test updating from a normal URI to an Arweave URI
    function testUpdateNormalToArweaveURI() public {
        string memory normalURI = "https://example.com";
        string memory arweaveURI = "ar://UPDATE_CID";
        testURI.storeURI(normalURI, false);
        testURI.updateURI(arweaveURI);
        assertEq(testURI.loadURI(), arweaveURI);
    }

    // Test loading an Arweave URI
    function testLoadArweaveURI() public {
        string memory arweaveURI = "ar://LOAD_CID";
        testURI.storeURI(arweaveURI, false);
        string memory loadedURI = testURI.loadURI();
        assertEq(loadedURI, arweaveURI);
    }

    // Test internal calls
}

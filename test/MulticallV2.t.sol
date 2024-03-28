// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test, console2} from "forge-std/Test.sol";
import {MockMultiCallImplementer} from "./mocks/MockMultiCallImplementer.sol";

contract MulticallTest is Test {
    MockMultiCallImplementer private testMultiCallContract;

    function setUp() public {
        testMultiCallContract = new MockMultiCallImplementer();
    }

    function test_InternalMulticall() public {
        uint256[] memory values = new uint256[](3);
        values[0] = 1;
        values[1] = 2;
        values[2] = 3;

        bytes[] memory returnData = testMultiCallContract.batchSetValuesAndEmit(values);

        assertEq(returnData.length, 3);
    }

    function test_InternalMulticallWithRevert() public {
        uint256[] memory values = new uint256[](3);
        values[0] = 1;
        values[1] = 2;
        values[2] = 69;

        vm.expectRevert(abi.encodeWithSelector(MockMultiCallImplementer.IllegalValue.selector, 69));
        bytes[] memory returnData = testMultiCallContract.batchSetValuesAndEmit(values);

        assertEq(returnData.length, 0);
    }

    function test_MulticallExternal() public {
        uint256[] memory values = new uint256[](3);
        values[0] = 1;
        values[1] = 2;
        values[2] = 3;

        bytes[] memory callData = new bytes[](values.length);

        for (uint256 i = 0; i < values.length; i++) {
            callData[i] = abi.encodeWithSelector(0xf6b9b7a0, i, values[i]);
        }

        bytes[] memory returnData = testMultiCallContract.multicall(callData);

        assertEq(returnData.length, 3);
    }
}

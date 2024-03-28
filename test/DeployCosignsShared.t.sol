// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test, console2} from "forge-std/Test.sol";
import {DeployCosignsShared} from "../script/DeployCosignsShared.s.sol";

contract DeployTest is Test {
    DeployCosignsShared internal deployScript;

    function setUp() public {
        deployScript = new DeployCosignsShared();
    }

    function test_Deploy() public {
        deployScript.run();
        assertEq(deployScript.success(), true);
    }
}

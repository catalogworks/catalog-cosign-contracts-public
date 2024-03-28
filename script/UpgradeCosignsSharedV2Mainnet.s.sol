// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";

import {CatalogCosigns} from "../src/shared/proxies/CatalogCosigns.sol";
import {CatalogCosignsImplementation} from "../src/shared/token/CatalogCosignsImplementationV2.sol";
import {ICosignTypes} from "../src/shared/interfaces/ICosignTypes.sol";

contract UpgradeCosignsSharedV2Mainnet is Script {
    CatalogCosigns proxyContract;
    CatalogCosignsImplementation newCosignContractImplementationV2;

    address public catalogDeployer;
    address public catalogFeeReceiver;

    bool public success;

    function setUp() public {}

    function run() public {
        // vm.deal(msg.sender, 10 ether);
        console2.log("starting deploy");
        console2.log("sender?", msg.sender);

        catalogDeployer = 0xB4bA57B82a6A5c85CF5C2428384EC97747735cd3;

        vm.startBroadcast();

        newCosignContractImplementationV2 = new CatalogCosignsImplementation();

        /// @dev replace with deployed contract address
        proxyContract = CatalogCosigns(payable(address(0x15e57847c5EEE553E0eAa247De0dFFeF28DD68eb)));

        CatalogCosignsImplementation(address(proxyContract)).upgradeToAndCall(
            address(newCosignContractImplementationV2), ""
        );

        success = true;

        vm.stopBroadcast();

        console2.log("deployed cosign implementation:", address(newCosignContractImplementationV2));
        console2.log("deployed cosign proxy:", address(proxyContract));
    }
}

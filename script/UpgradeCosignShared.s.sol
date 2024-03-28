// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";

import {CatalogCosigns} from "../src/shared/proxies/CatalogCosigns.sol";
import {CatalogCosignsImplementation} from "../src/shared/token/CatalogCosignsImplementation.sol";
import {ICosignTypes} from "../src/shared/interfaces/ICosignTypes.sol";

contract UpgradeCosignsShared is Script {
    CatalogCosigns proxyContract;
    CatalogCosignsImplementation newCosignContractImplementation;

    address public catalogDeployer;
    address public catalogFeeReceiver;

    bool public success;

    function setUp() public {}

    function run() public {
        // vm.deal(msg.sender, 10 ether);
        console2.log("starting deploy");
        console2.log("sender?", msg.sender);

        // @dev 0x5E164cC585f79EEf376bD76c867674f9E0f00722 is the optimism deployer address defined in project root encrypted keystore
        catalogDeployer = 0x5E164cC585f79EEf376bD76c867674f9E0f00722;
        catalogFeeReceiver = 0x5E164cC585f79EEf376bD76c867674f9E0f00722;

        vm.startBroadcast();

        newCosignContractImplementation = new CatalogCosignsImplementation();

        /// @dev replace with deployed contract address
        proxyContract = CatalogCosigns(payable(address(0xEEBd535f9Af662E029AD8666f729D08de41e98d5)));

        CatalogCosignsImplementation(address(proxyContract)).upgradeToAndCall(
            address(newCosignContractImplementation), ""
        );

        success = true;

        vm.stopBroadcast();

        console2.log("deployed cosign implementation:", address(newCosignContractImplementation));
        console2.log("deployed cosign proxy:", address(proxyContract));
    }
}

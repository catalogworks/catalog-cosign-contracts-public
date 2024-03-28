// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";

import {CatalogCosigns} from "../src/shared/proxies/CatalogCosigns.sol";
import {CatalogCosignsImplementation} from "../src/shared/token/CatalogCosignsImplementation.sol";
import {ICosignTypes} from "../src/shared/interfaces/ICosignTypes.sol";

contract DeployCosignsShared is Script {
    CatalogCosigns proxyContract;
    CatalogCosignsImplementation cosignContractImplementation;

    address public catalogDeployer;
    address public catalogFeeReceiver;

    bool public success;

    function run() public {
        console2.log("starting deploy");
        console2.log("sender?", msg.sender);

        // @dev 0x5E164cC585f79EEf376bD76c867674f9E0f00722 is the optimism testnet deployer address defined in project root encrypted keystore
        // @dev 0xB4bA57B82a6A5c85CF5C2428384EC97747735cd3 is the base mainnet deployer address defined in project root encrypted keystore
        catalogDeployer = 0xB4bA57B82a6A5c85CF5C2428384EC97747735cd3;
        // @dev 0x86D7f4F80aef83F18638681d4Ffcfee23b22C1Bd is the catalog admin safe for base mainnet
        catalogFeeReceiver = 0x86D7f4F80aef83F18638681d4Ffcfee23b22C1Bd;

        vm.startBroadcast();

        cosignContractImplementation = new CatalogCosignsImplementation();

        proxyContract = new CatalogCosigns(address(cosignContractImplementation));

        CatalogCosignsImplementation(address(proxyContract)).initialize(
            ICosignTypes.CosignInitData({
                _owner: catalogDeployer,
                _artistShare: 85,
                _platformShare: 15,
                _name: "Catalog Cosigns",
                _contractMetadataURI: "blah blah"
            })
        );

        success = true;

        vm.stopBroadcast();

        console2.log("deployed cosign implementation:", address(cosignContractImplementation));
        console2.log("deployed cosign proxy:", address(proxyContract));
    }
}

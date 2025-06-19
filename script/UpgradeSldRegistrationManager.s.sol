// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "contracts/SldRegistrationManager.sol";

/**
 * @title Upgrade SLD Registration Manager Script
 * @notice This script upgrades the SLD Registration Manager proxy to a new implementation
 * @dev Usage:
 *   Mainnet: forge script script/UpgradeSldRegistrationManager.s.sol:UpgradeSldRegistrationManagerScript --profile optimism-mainnet --broadcast --verify
 *   Testnet: forge script script/UpgradeSldRegistrationManager.s.sol:UpgradeSldRegistrationManagerScript --profile optimism-sepolia --broadcast --verify
 */
contract UpgradeSldRegistrationManagerScript is Script {
    // Chain-specific addresses
    struct NetworkConfig {
        address sldRegistrationManagerProxy;
    }

    mapping(uint256 => NetworkConfig) public networkConfigs;

    function setUp() public {
        // Optimism Mainnet (Chain ID: 10) - PROD: hns.id
        networkConfigs[10] = NetworkConfig({
            sldRegistrationManagerProxy: 0xfda87cc032cd641ac192027353e5b25261dfe6b3
        });

        // Optimism Sepolia (Chain ID: 11155420)
        networkConfigs[11155420] = NetworkConfig({
            sldRegistrationManagerProxy: 0x529B2b5B576c27769Ae0aB811F1655012f756C00
        });
    }

    function getNetworkConfig() internal view returns (NetworkConfig memory) {
        NetworkConfig memory config = networkConfigs[block.chainid];
        require(config.sldRegistrationManagerProxy != address(0), "Network not configured");
        return config;
    }

    function run() public {
        NetworkConfig memory config = getNetworkConfig();

        // Private key is automatically loaded from the profile
        vm.startBroadcast();

        console.log("Starting SLD Registration Manager upgrade...");
        console.log("Chain ID:", block.chainid);
        console.log("Proxy address:", config.sldRegistrationManagerProxy);
        console.log("Deployer:", msg.sender);

        // 1. Deploy new implementation
        SldRegistrationManager newImplementation = new SldRegistrationManager();
        console.log("New implementation deployed at:", address(newImplementation));

        // 2. Get proxy admin interface
        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(
            payable(config.sldRegistrationManagerProxy)
        );

        // 3. Upgrade to new implementation
        proxy.upgradeTo(address(newImplementation));
        console.log("Proxy upgraded to new implementation");

        vm.stopBroadcast();

        // 4. Verify the upgrade worked
        console.log("Verifying upgrade...");
        SldRegistrationManager manager = SldRegistrationManager(config.sldRegistrationManagerProxy);

        // Test that the new function exists (this will revert if upgrade failed)
        try manager.sldCountPerTld(bytes32(0)) returns (uint256 count) {
            console.log("✅ Upgrade successful - sldCountPerTld function is available");
            console.log("SLD count for test namehash:", count);
        } catch {
            console.log("❌ Upgrade verification failed - sldCountPerTld function not available");
        }

        console.log("SLD Registration Manager upgrade completed!");
    }

    /**
     * @notice Alternative function to just verify an existing deployment
     * @dev Run with: forge script script/UpgradeSldRegistrationManager.s.sol:UpgradeSldRegistrationManagerScript --sig "verify()" --profile optimism-mainnet
     */
    function verify() public view {
        NetworkConfig memory config = getNetworkConfig();

        console.log("Verifying SLD Registration Manager at:", config.sldRegistrationManagerProxy);
        console.log("Chain ID:", block.chainid);

        SldRegistrationManager manager = SldRegistrationManager(config.sldRegistrationManagerProxy);

        try manager.sldCountPerTld(bytes32(0)) returns (uint256 count) {
            console.log("✅ sldCountPerTld function is available");
            console.log("SLD count for test namehash:", count);
        } catch {
            console.log("❌ sldCountPerTld function not available - upgrade needed");
        }
    }
}

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
 *   Mainnet: FOUNDRY_PROFILE=optimism-mainnet forge script script/UpgradeSldRegistrationManager.s.sol:UpgradeSldRegistrationManagerScript --broadcast --verify
 *   Testnet: FOUNDRY_PROFILE=optimism-sepolia forge script script/UpgradeSldRegistrationManager.s.sol:UpgradeSldRegistrationManagerScript --broadcast --verify
 *
 * @dev NOTE: This script only performs the proxy upgrade. The SLD Registration Manager
 *      doesn't require additional configuration for the TLD burning feature.
 *      Expected contract owner: 0xa90D04E5FaC9ba49520749711a12c3E5d0D9D6dA
 */
contract UpgradeSldRegistrationManagerScript is Script {
    // Production contract owner address (from Deploy.s.sol)
    address private constant CONTRACT_OWNER = 0xa90D04E5FaC9ba49520749711a12c3E5d0D9D6dA;

    // Chain-specific addresses
    struct NetworkConfig {
        address sldRegistrationManagerProxy;
    }

    mapping(uint256 => NetworkConfig) public networkConfigs;

    function setUp() public {
        // Optimism Mainnet (Chain ID: 10) - PROD: hns.id
        networkConfigs[10] = NetworkConfig({
            sldRegistrationManagerProxy: 0xfda87CC032cD641ac192027353e5B25261dfe6b3
        });

        // Optimism Sepolia (Chain ID: 11155420)
        networkConfigs[11155420] = NetworkConfig({
            sldRegistrationManagerProxy: 0x529B2b5B576c27769Ae0aB811F1655012f756C00
        });
    }

    function getNetworkConfig() internal returns (NetworkConfig memory) {
        console.log("Current chain ID:", block.chainid);
        NetworkConfig memory config = networkConfigs[block.chainid];
        require(
            config.sldRegistrationManagerProxy != address(0),
            string(
                abi.encodePacked(
                    "Network not configured for chain ID: ",
                    vm.toString(block.chainid)
                )
            )
        );
        return config;
    }

    function run() public {
        NetworkConfig memory config = getNetworkConfig();

        // Private key is automatically loaded from the profile
        vm.startBroadcast();

        console.log("Starting SLD Registration Manager upgrade...");
        console.log("Chain ID:", block.chainid);
        console.log("Proxy address:", config.sldRegistrationManagerProxy);
        console.log("Expected Contract Owner:", CONTRACT_OWNER);
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
            console.log("Upgrade successful - sldCountPerTld function is available");
            console.log("SLD count for test namehash:", count);
        } catch {
            console.log("Upgrade verification failed - sldCountPerTld function not available");
        }

        console.log("SLD Registration Manager upgrade completed!");
    }

    /**
     * @notice Alternative function to just verify an existing deployment
     * @dev Run with: FOUNDRY_PROFILE=optimism-mainnet forge script script/UpgradeSldRegistrationManager.s.sol:UpgradeSldRegistrationManagerScript --sig "verify()"
     */
    function verify() public {
        NetworkConfig memory config = getNetworkConfig();

        console.log("Verifying SLD Registration Manager at:", config.sldRegistrationManagerProxy);
        console.log("Chain ID:", block.chainid);

        SldRegistrationManager manager = SldRegistrationManager(config.sldRegistrationManagerProxy);

        try manager.sldCountPerTld(bytes32(0)) returns (uint256 count) {
            console.log("sldCountPerTld function is available");
            console.log("SLD count for test namehash:", count);
        } catch {
            console.log("sldCountPerTld function not available - upgrade needed");
        }
    }
}

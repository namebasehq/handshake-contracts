// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "contracts/TldClaimManager.sol";
import "interfaces/ISldRegistrationManager.sol";

/**
 * @title Upgrade TLD Claim Manager Script
 * @notice This script upgrades the TLD Claim Manager proxy to a new implementation with burning functionality
 * @dev Usage:
 *   Mainnet: forge script script/UpgradeTldClaimManager.s.sol:UpgradeTldClaimManagerScript --profile optimism-mainnet --broadcast --verify
 *   Testnet: forge script script/UpgradeTldClaimManager.s.sol:UpgradeTldClaimManagerScript --profile optimism-sepolia --broadcast --verify
 */
contract UpgradeTldClaimManagerScript is Script {
    // Chain-specific addresses
    struct NetworkConfig {
        address tldClaimManagerProxy;
        address sldRegistrationManagerProxy;
        address authorizedSigner;
    }

    mapping(uint256 => NetworkConfig) public networkConfigs;

    function setUp() public {
        // Optimism Mainnet (Chain ID: 10) - PROD: hns.id
        networkConfigs[10] = NetworkConfig({
            tldClaimManagerProxy: 0x9209397263427413817Afc6957A434cF62C02c68,
            sldRegistrationManagerProxy: 0xfda87cc032cd641ac192027353e5b25261dfe6b3,
            authorizedSigner: 0xdA29bd6a46B89Cc5a5a404663524132D2f7Df10f
        });

        // Optimism Sepolia (Chain ID: 11155420)
        networkConfigs[11155420] = NetworkConfig({
            tldClaimManagerProxy: 0x82eba02627F0b67B0eabdE7e7c2390183AE4bF4D,
            sldRegistrationManagerProxy: 0x529B2b5B576c27769Ae0aB811F1655012f756C00,
            authorizedSigner: 0xdA29bd6a46B89Cc5a5a404663524132D2f7Df10f
        });
    }

    function getNetworkConfig() internal view returns (NetworkConfig memory) {
        NetworkConfig memory config = networkConfigs[block.chainid];
        require(config.tldClaimManagerProxy != address(0), "Network not configured");
        return config;
    }

    function run() public {
        NetworkConfig memory config = getNetworkConfig();

        // Private key is automatically loaded from the profile
        vm.startBroadcast();

        console.log("Starting TLD Claim Manager upgrade...");
        console.log("Chain ID:", block.chainid);
        console.log("TLD Claim Manager Proxy:", config.tldClaimManagerProxy);
        console.log("SLD Registration Manager Proxy:", config.sldRegistrationManagerProxy);
        console.log("Authorized Signer:", config.authorizedSigner);
        console.log("Deployer:", msg.sender);

        // 1. Deploy new implementation
        TldClaimManager newImplementation = new TldClaimManager();
        console.log("New implementation deployed at:", address(newImplementation));

        // 2. Get proxy admin interface
        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(
            payable(config.tldClaimManagerProxy)
        );

        // 3. Upgrade to new implementation
        proxy.upgradeTo(address(newImplementation));
        console.log("Proxy upgraded to new implementation");

        vm.stopBroadcast();

        // 4. Configure the upgraded contract (as contract owner, not proxy owner)
        // Note: This assumes the same private key can perform both proxy upgrade and contract admin functions
        // If different keys are needed, you'll need to run the configure() function separately
        vm.startBroadcast();

        TldClaimManager manager = TldClaimManager(config.tldClaimManagerProxy);

        console.log("Configuring upgraded contract...");

        // Set the SLD Registration Manager
        manager.setSldRegistrationManager(
            ISldRegistrationManager(config.sldRegistrationManagerProxy)
        );
        console.log("SLD Registration Manager set to:", config.sldRegistrationManagerProxy);

        // Add authorized signer for burning
        manager.updateSigner(config.authorizedSigner, true);
        console.log("Authorized signer added:", config.authorizedSigner);

        vm.stopBroadcast();

        // 5. Verify the upgrade worked
        console.log("Verifying upgrade...");

        // Test that the new functions exist
        try manager.sldRegistrationManager() returns (ISldRegistrationManager sldManager) {
            console.log("✅ Upgrade successful - sldRegistrationManager function is available");
            console.log("SLD Registration Manager:", address(sldManager));
        } catch {
            console.log(
                "❌ Upgrade verification failed - sldRegistrationManager function not available"
            );
        }

        try manager.ValidSigner(config.authorizedSigner) returns (bool isValid) {
            console.log("✅ ValidSigner function is available");
            console.log("Authorized signer status:", isValid);
        } catch {
            console.log("❌ ValidSigner function not available");
        }

        console.log("TLD Claim Manager upgrade completed!");
    }

    /**
     * @notice Alternative function to just verify an existing deployment
     * @dev Run with: forge script script/UpgradeTldClaimManager.s.sol:UpgradeTldClaimManagerScript --sig "verify()" --profile optimism-mainnet
     */
    function verify() public view {
        NetworkConfig memory config = getNetworkConfig();

        console.log("Verifying TLD Claim Manager at:", config.tldClaimManagerProxy);
        console.log("Chain ID:", block.chainid);

        TldClaimManager manager = TldClaimManager(config.tldClaimManagerProxy);

        try manager.sldRegistrationManager() returns (ISldRegistrationManager sldManager) {
            console.log("✅ sldRegistrationManager function is available");
            console.log("SLD Registration Manager:", address(sldManager));
        } catch {
            console.log("❌ sldRegistrationManager function not available - upgrade needed");
        }

        try manager.ValidSigner(config.authorizedSigner) returns (bool isValid) {
            console.log("✅ ValidSigner function is available");
            console.log("Authorized signer status:", isValid);
        } catch {
            console.log("❌ ValidSigner function not available - upgrade needed");
        }

        try manager.DOMAIN_SEPARATOR() returns (bytes32 domainSeparator) {
            console.log("✅ DOMAIN_SEPARATOR is available");
            console.log("Domain separator:", vm.toString(domainSeparator));
        } catch {
            console.log("❌ DOMAIN_SEPARATOR not available - upgrade needed");
        }
    }

    /**
     * @notice Function to configure post-upgrade settings
     * @dev Run with: forge script script/UpgradeTldClaimManager.s.sol:UpgradeTldClaimManagerScript --sig "configure()" --profile optimism-mainnet --broadcast
     */
    function configure() public {
        NetworkConfig memory config = getNetworkConfig();

        vm.startBroadcast();

        TldClaimManager manager = TldClaimManager(config.tldClaimManagerProxy);

        console.log("Configuring TLD Claim Manager...");
        console.log("Chain ID:", block.chainid);

        // Set the SLD Registration Manager
        manager.setSldRegistrationManager(
            ISldRegistrationManager(config.sldRegistrationManagerProxy)
        );
        console.log("SLD Registration Manager set to:", config.sldRegistrationManagerProxy);

        // Add authorized signer for burning
        manager.updateSigner(config.authorizedSigner, true);
        console.log("Authorized signer added:", config.authorizedSigner);

        vm.stopBroadcast();

        console.log("Configuration completed!");
    }
}

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
 *   Step 1 - Deploy new implementation (can use any profile):
 *     FOUNDRY_PROFILE=optimism-sepolia forge script script/UpgradeTldClaimManager.s.sol:UpgradeTldClaimManagerScript --broadcast
 *
 *   Step 2 - Upgrade proxy (requires proxy owner):
 *     FOUNDRY_PROFILE=optimism-sepolia-proxy forge script script/UpgradeTldClaimManager.s.sol:UpgradeTldClaimManagerScript --sig "upgrade(address)" <IMPLEMENTATION_ADDRESS> --broadcast
 *
 *   Step 3 - Configure contract (requires contract owner):
 *     FOUNDRY_PROFILE=optimism-sepolia-owner forge script script/UpgradeTldClaimManager.s.sol:UpgradeTldClaimManagerScript --sig "configure()" --broadcast
 
 this was the the final command i used to deploy

 forge script script/UpgradeTldClaimManager.s.sol:UpgradeTldClaimManagerScript --broadcast --verify --rpc-url https://sepolia.optimism.io --sender 0x175F303781Efe881Ce40A511517186DbF364b3a7 --private-key $TEST_PRIVATE_KEY
 forge script script/UpgradeTldClaimManager.s.sol:UpgradeTldClaimManagerScript --sig "upgrade(address)" 0x3d39e62E3f42771734FE13DD9227A6F75b9fE60d --rpc-url https://sepolia.optimism.io --private-key $TEST_PROXY_PRIVATE_KEY --broadcast
 forge script script/UpgradeTldClaimManager.s.sol:UpgradeTldClaimManagerScript --sig "configure()" --rpc-url https://sepolia.optimism.io --private-key $TEST_PRIVATE_KEY --broadcast 
 */
contract UpgradeTldClaimManagerScript is Script {
    // Production contract owner address (from Deploy.s.sol)
    address private constant CONTRACT_OWNER = 0xa90D04E5FaC9ba49520749711a12c3E5d0D9D6dA;

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
            sldRegistrationManagerProxy: 0xfda87CC032cD641ac192027353e5B25261dfe6b3,
            authorizedSigner: 0xdA29bd6a46B89Cc5a5a404663524132D2f7Df10f
        });

        // Optimism Sepolia (Chain ID: 11155420)
        networkConfigs[11155420] = NetworkConfig({
            tldClaimManagerProxy: 0x82eba02627F0b67B0eabdE7e7c2390183AE4bF4D,
            sldRegistrationManagerProxy: 0x529B2b5B576c27769Ae0aB811F1655012f756C00,
            authorizedSigner: 0xdA29bd6a46B89Cc5a5a404663524132D2f7Df10f
        });
    }

    function getNetworkConfig() internal returns (NetworkConfig memory) {
        console.log("Current chain ID:", block.chainid);
        NetworkConfig memory config = networkConfigs[block.chainid];
        require(
            config.tldClaimManagerProxy != address(0),
            string(
                abi.encodePacked(
                    "Network not configured for chain ID: ",
                    vm.toString(block.chainid)
                )
            )
        );
        return config;
    }

    /**
     * @notice Default function - only deploys new implementation
     */
    function run() public {
        NetworkConfig memory config = getNetworkConfig();

        vm.startBroadcast();


        console.log("Deploying new TLD Claim Manager implementation...");
        console.log("Chain ID:", block.chainid);
        console.log("Deployer:", msg.sender);

        // Deploy new implementation
        TldClaimManager newImplementation = new TldClaimManager();
        console.log("New implementation deployed at:", address(newImplementation));

        vm.stopBroadcast();

        console.log("Deployment completed!");
        console.log("Next steps:");
        console.log("1. Run upgrade() with proxy owner's private key");
        console.log("2. Run configure() with contract owner's private key");
    }

    /**
     * @notice Upgrade the proxy to new implementation (requires PROXY_OWNER_PRIVATE_KEY)
     * @param implementationAddress Address of the new implementation contract
     */
    function upgrade(address implementationAddress) public {
        NetworkConfig memory config = getNetworkConfig();

        vm.startBroadcast();

        console.log("Upgrading TLD Claim Manager proxy...");
        console.log("Chain ID:", block.chainid);
        console.log("TLD Claim Manager Proxy:", config.tldClaimManagerProxy);
        console.log("New Implementation:", implementationAddress);
        console.log("Deployer (should be proxy owner):", msg.sender);

        // Get proxy admin interface
        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(
            payable(config.tldClaimManagerProxy)
        );

        // Upgrade to new implementation
        proxy.upgradeTo(implementationAddress);
        console.log("Proxy upgraded to new implementation");

        vm.stopBroadcast();

        // Verify the upgrade worked
        console.log("Verifying proxy upgrade...");
        TldClaimManager manager = TldClaimManager(config.tldClaimManagerProxy);

        try manager.sldRegistrationManager() returns (ISldRegistrationManager) {
            console.log("Upgrade successful - new functions are available");
        } catch {
            console.log("Upgrade verification failed - new functions not available");
        }

        console.log("Proxy upgrade completed!");
        console.log("Next step: Run configure() with the contract owner's private key");
    }

    /**
     * @notice Alternative function to just verify an existing deployment
     * @dev Run with: FOUNDRY_PROFILE=optimism-mainnet forge script script/UpgradeTldClaimManager.s.sol:UpgradeTldClaimManagerScript --sig "verify()"
     */
    function verify() public {
        NetworkConfig memory config = getNetworkConfig();

        console.log("Verifying TLD Claim Manager at:", config.tldClaimManagerProxy);
        console.log("Chain ID:", block.chainid);

        TldClaimManager manager = TldClaimManager(config.tldClaimManagerProxy);

        try manager.sldRegistrationManager() returns (ISldRegistrationManager sldManager) {
            console.log("sldRegistrationManager function is available");
            console.log("SLD Registration Manager:", address(sldManager));
        } catch {
            console.log("sldRegistrationManager function not available - upgrade needed");
        }

        try manager.ValidSigner(config.authorizedSigner) returns (bool isValid) {
            console.log("ValidSigner function is available");
            console.log("Authorized signer status:", isValid);
        } catch {
            console.log("ValidSigner function not available - upgrade needed");
        }

        try manager.DOMAIN_SEPARATOR() returns (bytes32 domainSeparator) {
            console.log("DOMAIN_SEPARATOR is available");
            console.log("Domain separator:", vm.toString(domainSeparator));
        } catch {
            console.log("DOMAIN_SEPARATOR not available - upgrade needed");
        }
    }

    /**
     * @notice Function to configure post-upgrade settings
     * @dev Run with: FOUNDRY_PROFILE=optimism-mainnet forge script script/UpgradeTldClaimManager.s.sol:UpgradeTldClaimManagerScript --sig "configure()" --broadcast
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

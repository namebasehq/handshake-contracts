// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "contracts/SldRegistrationManager.sol";
import {Namehash} from "utils/Namehash.sol";

/**
 * @title Upgrade SLD Registration Manager Script
 * @notice This script upgrades the SLD Registration Manager proxy to a new implementation
 * @dev Usage:
 *   Step 1 - Deploy new implementation (can use any profile):
 *     FOUNDRY_PROFILE=optimism-sepolia forge script script/UpgradeSldRegistrationManager.s.sol:UpgradeSldRegistrationManagerScript --broadcast
 *
 *   Step 2 - Upgrade proxy (requires proxy owner):
 *     FOUNDRY_PROFILE=optimism-sepolia-proxy forge script script/UpgradeSldRegistrationManager.s.sol:UpgradeSldRegistrationManagerScript --sig "upgrade(address)" <IMPLEMENTATION_ADDRESS> --broadcast
 *
 *   Step 3 - Verify upgrade (read-only):
 *     FOUNDRY_PROFILE=optimism-sepolia forge script script/UpgradeSldRegistrationManager.s.sol:UpgradeSldRegistrationManagerScript --sig "verify()"
 *
 *  // update command
 *  forge script script/UpgradeSldRegistrationManager.s.sol:UpgradeSldRegistrationManagerScript --sig "setSldCountsFromJson(string)" "script/data/sld-counts.json" --rpc-url https://sepolia.optimism.io --private-key $TEST_PRIVATE_KEY
 */
contract UpgradeSldRegistrationManagerScript is Script {
    // Production contract owner address (from Deploy.s.sol)
    address private constant CONTRACT_OWNER = 0xa90D04E5FaC9ba49520749711a12c3E5d0D9D6dA;

    // Struct for TLD data from JSON
    struct TldData {
        string name;
        uint256 sldCount;
    }

    // Chain-specific addresses
    struct NetworkConfig {
        address sldRegistrationManagerProxy;
    }

    mapping(uint256 => NetworkConfig) public networkConfigs;

    function setUp() public {
        // Optimism Mainnet (Chain ID: 10) - PROD: hns.id
        networkConfigs[10] = NetworkConfig({sldRegistrationManagerProxy: 0xfda87CC032cD641ac192027353e5B25261dfe6b3});

        // Optimism Sepolia (Chain ID: 11155420)
        networkConfigs[11155420] =
            NetworkConfig({sldRegistrationManagerProxy: 0x529B2b5B576c27769Ae0aB811F1655012f756C00});
    }

    function getNetworkConfig() internal returns (NetworkConfig memory) {
        console.log("Current chain ID:", block.chainid);
        NetworkConfig memory config = networkConfigs[block.chainid];
        require(
            config.sldRegistrationManagerProxy != address(0),
            string(abi.encodePacked("Network not configured for chain ID: ", vm.toString(block.chainid)))
        );
        return config;
    }

    /**
     * @notice Default function - only deploys new implementation
     */
    function run() public {
        NetworkConfig memory config = getNetworkConfig();

        vm.startBroadcast();

        console.log("Deploying new SLD Registration Manager implementation...");
        console.log("Chain ID:", block.chainid);
        console.log("Deployer:", msg.sender);

        // Deploy new implementation
        SldRegistrationManager newImplementation = new SldRegistrationManager();
        console.log("New implementation deployed at:", address(newImplementation));

        vm.stopBroadcast();

        console.log("Deployment completed!");
        console.log("Next steps:");
        console.log("1. Run upgrade() with proxy owner's private key");
        console.log("2. Run verify() to confirm upgrade worked");
    }

    /**
     * @notice Upgrade the proxy to new implementation (requires PROXY_OWNER_PRIVATE_KEY)
     * @param implementationAddress Address of the new implementation contract
     */
    function upgrade(address implementationAddress) public {
        NetworkConfig memory config = getNetworkConfig();

        vm.startBroadcast();

        console.log("Upgrading SLD Registration Manager proxy...");
        console.log("Chain ID:", block.chainid);
        console.log("SLD Registration Manager Proxy:", config.sldRegistrationManagerProxy);
        console.log("New Implementation:", implementationAddress);
        console.log("Deployer (should be proxy owner):", msg.sender);

        // Get proxy admin interface
        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(payable(config.sldRegistrationManagerProxy));

        // Upgrade to new implementation
        proxy.upgradeTo(implementationAddress);
        console.log("Proxy upgraded to new implementation");

        vm.stopBroadcast();

        // Verify the upgrade worked
        console.log("Verifying proxy upgrade...");
        SldRegistrationManager manager = SldRegistrationManager(config.sldRegistrationManagerProxy);

        try manager.sldCountPerTld(bytes32(0)) returns (uint256 count) {
            console.log("Upgrade successful - new functions are available");
            console.log("SLD count for test namehash:", count);
        } catch {
            console.log("Upgrade verification failed - new functions not available");
        }

        console.log("Proxy upgrade completed!");
    }

    /**
     * @notice Set SLD counts from JSON file (requires CONTRACT_OWNER_PRIVATE_KEY)
     * @dev Run with: forge script script/UpgradeSldRegistrationManager.s.sol:UpgradeSldRegistrationManagerScript --sig "setSldCountsFromJson(string)" "script/data/sld-counts.json" --rpc-url https://sepolia.optimism.io --private-key $TEST_OWNER_PRIVATE_KEY --broadcast
     * @param jsonFilePath Path to JSON file containing TLD data
     */
    function setSldCountsFromJson(string memory jsonFilePath) public {
        NetworkConfig memory config = getNetworkConfig();

        // Read and parse JSON file
        string memory json = vm.readFile(jsonFilePath);
        bytes memory parsedJson = vm.parseJson(json);

        // Decode the JSON into arrays
        TldData[] memory tldData = abi.decode(parsedJson, (TldData[]));

        console.log("Setting SLD counts from JSON file:", jsonFilePath);
        console.log("Chain ID:", block.chainid);
        console.log("SLD Registration Manager:", config.sldRegistrationManagerProxy);
        console.log("Number of TLDs to update:", tldData.length);
        console.log("Deployer (should be contract owner):", msg.sender);

        vm.startBroadcast();

        SldRegistrationManager manager = SldRegistrationManager(config.sldRegistrationManagerProxy);

        for (uint256 i = 0; i < tldData.length; i++) {
            console.log("Setting TLD", tldData[i].name, "to count", tldData[i].sldCount);
            bytes32 namehash = Namehash.getTldNamehash(tldData[i].name);
            console.log("Calculated namehash:", vm.toString(namehash));
            manager.initializeSldCount(namehash, tldData[i].sldCount);
        }

        vm.stopBroadcast();

        console.log("SLD counts updated successfully from JSON!");
    }

    /**
     * @notice Set SLD count for existing TLDs (requires CONTRACT_OWNER_PRIVATE_KEY)
     * @dev Run with: forge script script/UpgradeSldRegistrationManager.s.sol:UpgradeSldRegistrationManagerScript --sig "setSldCounts(bytes32[],uint256[])" "[0x...]" "[1,2,3]" --rpc-url https://sepolia.optimism.io --private-key $TEST_OWNER_PRIVATE_KEY --broadcast
     * @param tldNamehashes Array of TLD namehashes
     * @param counts Array of SLD counts for each TLD
     */
    function setSldCounts(bytes32[] memory tldNamehashes, uint256[] memory counts) public {
        require(tldNamehashes.length == counts.length, "Arrays must have same length");

        NetworkConfig memory config = getNetworkConfig();

        vm.startBroadcast();

        console.log("Setting SLD counts for existing TLDs...");
        console.log("Chain ID:", block.chainid);
        console.log("SLD Registration Manager:", config.sldRegistrationManagerProxy);
        console.log("Number of TLDs to update:", tldNamehashes.length);
        console.log("Deployer (should be contract owner):", msg.sender);

        SldRegistrationManager manager = SldRegistrationManager(config.sldRegistrationManagerProxy);

        for (uint256 i = 0; i < tldNamehashes.length; i++) {
            console.log("Setting TLD", vm.toString(tldNamehashes[i]), "to count", counts[i]);
            manager.initializeSldCount(tldNamehashes[i], counts[i]);
        }

        vm.stopBroadcast();

        console.log("SLD counts updated successfully!");
    }

    /**
     * @notice Set SLD count for a single TLD (requires CONTRACT_OWNER_PRIVATE_KEY)
     * @dev Run with: forge script script/UpgradeSldRegistrationManager.s.sol:UpgradeSldRegistrationManagerScript --sig "setSingleSldCount(bytes32,uint256)" 0x... 5 --rpc-url https://sepolia.optimism.io --private-key $TEST_OWNER_PRIVATE_KEY --broadcast
     * @param tldNamehash The TLD namehash
     * @param count The SLD count for this TLD
     */
    function setSingleSldCount(bytes32 tldNamehash, uint256 count) public {
        NetworkConfig memory config = getNetworkConfig();

        vm.startBroadcast();

        console.log("Setting SLD count for single TLD...");
        console.log("Chain ID:", block.chainid);
        console.log("SLD Registration Manager:", config.sldRegistrationManagerProxy);
        console.log("TLD Namehash:", vm.toString(tldNamehash));
        console.log("Count:", count);
        console.log("Deployer (should be contract owner):", msg.sender);

        SldRegistrationManager manager = SldRegistrationManager(config.sldRegistrationManagerProxy);
        manager.initializeSldCount(tldNamehash, count);

        vm.stopBroadcast();

        console.log("SLD count updated successfully!");
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

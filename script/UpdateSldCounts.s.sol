// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "src/contracts/SldRegistrationManager.sol";
import "src/utils/Namehash.sol";

/**
 * @title UpdateSldCountsScript
 * @notice Script to update SLD counts for existing TLDs
 * @dev This script uses the initializeSldCount function to set SLD counts for TLDs
 *      Run with: forge script script/UpdateSldCounts.s.sol:UpdateSldCountsScript --sig "updateSldCounts()" --rpc-url <RPC_URL> --private-key $OWNER_PRIVATE_KEY --broadcast
 */
contract UpdateSldCountsScript is Script {
    struct TldSldData {
        string tldName;
        bytes32 namehash;
        uint256 sldCount;
    }

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
     * @notice Update SLD counts for all TLDs with the provided data
     * @dev This function contains the hardcoded TLD data and updates all counts
     */
    function updateSldCounts() public {
        NetworkConfig memory config = getNetworkConfig();

        // TLD data provided by user (excluding zeros since that's the default)
        TldSldData[13] memory tldData = [
            TldSldData("alex2", 0x63104b66444bbd5ee0396a62569bb5ff8658155917254b8eb23a5fa3ce28af25, 3),
            TldSldData("alex3", 0x8c28f16ed201cc1fff54589c4e8a9447b57beab60f5118dc9827dfda27504b10, 4),
            TldSldData("beta", 0x0226e31683dcf05f1f00505450f5be655e35f32d6be013442a061ef644b2b844, 12),
            TldSldData("demo", 0xa0fdb6f44f45e037cf69966fc429673921ca3c688f705e18a58b36b021c536ea, 1),
            TldSldData("falci", 0x720060ff870e87284a457612f73a83277d2d1e1d802b8d2d372b8c849e436ff6, 5),
            TldSldData("foo", 0xe9242feec0bae9a1ed162b28c15e876119ba849b70a9e4023d1cb765abe0dd14, 12),
            TldSldData("foobar", 0xe3b6b2b0b7c16bb9e5ff03b8cb4dba5cb6a6352e05b233b5d5b9abe0056cd8a1, 66),
            TldSldData("handycon", 0x90426cea4e51c3631535a1f19eebcea253d4d1c3301de611871fd8260753f967, 1),
            TldSldData("localhost", 0xa67149540740c5df90a1915276e95faf9544477b57c6b69b93887da91d06756b, 21),
            TldSldData("sam", 0xd322a4b44ea3f7cbcaa91969211136ce1da0d56bee139d313479a444fa04583c, 33),
            TldSldData("vercel", 0xd0d40ba9106295eb8ca27fef46b62f28aa40437430d9800375a5593cd52ab902, 25),
            TldSldData("wallet", 0x1e3f482b3363eb4710dae2cb2183128e272eafbe137f686851c1caea32502230, 11),
            TldSldData("test4", 0x4e6651ae851ae03870ee069523fd893319ddfbec1a209387ad3e0d4eb7f477c7, 1)
        ];

        console.log("Updating SLD counts for TLDs...");
        console.log("Chain ID:", block.chainid);
        console.log("SLD Registration Manager:", config.sldRegistrationManagerProxy);
        console.log("Number of TLDs to update:", tldData.length);
        console.log("Deployer (should be contract owner):", msg.sender);

        vm.startBroadcast();

        SldRegistrationManager manager = SldRegistrationManager(config.sldRegistrationManagerProxy);

        // Verify we can call the function (will revert if not owner)
        console.log("Verifying contract owner permissions...");

        for (uint256 i = 0; i < tldData.length; i++) {
            console.log(
                string(
                    abi.encodePacked(
                        "Setting TLD '",
                        tldData[i].tldName,
                        "' (",
                        vm.toString(tldData[i].namehash),
                        ") to count: ",
                        vm.toString(tldData[i].sldCount)
                    )
                )
            );

            // Verify the namehash matches what we expect for the TLD name
            bytes32 calculatedNamehash = Namehash.getTldNamehash(tldData[i].tldName);
            require(
                calculatedNamehash == tldData[i].namehash,
                string(
                    abi.encodePacked(
                        "Namehash mismatch for TLD '",
                        tldData[i].tldName,
                        "'. Expected: ",
                        vm.toString(calculatedNamehash),
                        ", Got: ",
                        vm.toString(tldData[i].namehash)
                    )
                )
            );

            // Set the SLD count
            manager.initializeSldCount(tldData[i].namehash, tldData[i].sldCount);
        }

        vm.stopBroadcast();

        console.log("SLD counts updated successfully!");
        console.log("Verification: Reading back some counts...");

        // Verify a few updates worked
        for (uint256 i = 0; i < 5 && i < tldData.length; i++) {
            uint256 actualCount = manager.sldCountPerTld(tldData[i].namehash);
            console.log(
                string(
                    abi.encodePacked(
                        "TLD '",
                        tldData[i].tldName,
                        "' count: ",
                        vm.toString(actualCount),
                        " (expected: ",
                        vm.toString(tldData[i].sldCount),
                        ")"
                    )
                )
            );
            require(actualCount == tldData[i].sldCount, "Count verification failed");
        }

        console.log("Verification successful!");
    }

    /**
     * @notice Update SLD count for a specific TLD by name
     * @dev Run with: forge script script/UpdateSldCounts.s.sol:UpdateSldCountsScript --sig "updateSingleTld(string,uint256)" "example" 42 --rpc-url <RPC_URL> --private-key $OWNER_PRIVATE_KEY --broadcast
     * @param tldName The TLD name (e.g., "foo", "test")
     * @param sldCount The SLD count to set
     */
    function updateSingleTld(string memory tldName, uint256 sldCount) public {
        NetworkConfig memory config = getNetworkConfig();

        bytes32 tldNamehash = Namehash.getTldNamehash(tldName);

        console.log("Updating single TLD...");
        console.log("Chain ID:", block.chainid);
        console.log("SLD Registration Manager:", config.sldRegistrationManagerProxy);
        console.log("TLD Name:", tldName);
        console.log("TLD Namehash:", vm.toString(tldNamehash));
        console.log("SLD Count:", sldCount);
        console.log("Deployer (should be contract owner):", msg.sender);

        vm.startBroadcast();

        SldRegistrationManager manager = SldRegistrationManager(config.sldRegistrationManagerProxy);
        manager.initializeSldCount(tldNamehash, sldCount);

        vm.stopBroadcast();

        // Verify the update
        uint256 actualCount = manager.sldCountPerTld(tldNamehash);
        console.log("Updated count:", actualCount);
        require(actualCount == sldCount, "Count verification failed");

        console.log("Single TLD update successful!");
    }

    /**
     * @notice View current SLD counts for all TLDs in our dataset
     * @dev Run with: forge script script/UpdateSldCounts.s.sol:UpdateSldCountsScript --sig "viewCurrentCounts()" --rpc-url <RPC_URL>
     */
    function viewCurrentCounts() public {
        NetworkConfig memory config = networkConfigs[block.chainid];
        require(config.sldRegistrationManagerProxy != address(0), "Network not configured");

        // TLD data for viewing (includes all TLDs for complete status check)
        TldSldData[18] memory tldData = [
            TldSldData("alex2", 0x63104b66444bbd5ee0396a62569bb5ff8658155917254b8eb23a5fa3ce28af25, 3),
            TldSldData("alex3", 0x8c28f16ed201cc1fff54589c4e8a9447b57beab60f5118dc9827dfda27504b10, 4),
            TldSldData("alex4", 0x0dfed98800adb707957ec663e032bf21c431d6f2ad671eae8a3d2301c9b29598, 0),
            TldSldData("aox", 0x4061934e342f734e3e517c1358419981afc8dd53fb0ffb352f6d6a279f7182d4, 0),
            TldSldData("beta", 0x0226e31683dcf05f1f00505450f5be655e35f32d6be013442a061ef644b2b844, 12),
            TldSldData("demo", 0xa0fdb6f44f45e037cf69966fc429673921ca3c688f705e18a58b36b021c536ea, 1),
            TldSldData("falci", 0x720060ff870e87284a457612f73a83277d2d1e1d802b8d2d372b8c849e436ff6, 5),
            TldSldData("foo", 0xe9242feec0bae9a1ed162b28c15e876119ba849b70a9e4023d1cb765abe0dd14, 12),
            TldSldData("foobar", 0xe3b6b2b0b7c16bb9e5ff03b8cb4dba5cb6a6352e05b233b5d5b9abe0056cd8a1, 66),
            TldSldData("handycon", 0x90426cea4e51c3631535a1f19eebcea253d4d1c3301de611871fd8260753f967, 1),
            TldSldData("localhost", 0xa67149540740c5df90a1915276e95faf9544477b57c6b69b93887da91d06756b, 21),
            TldSldData("sam", 0xd322a4b44ea3f7cbcaa91969211136ce1da0d56bee139d313479a444fa04583c, 33),
            TldSldData("test", 0x04f740db81dc36c853ab4205bddd785f46e79ccedca351fc6dfcbd8cc9a33dd6, 0),
            TldSldData("test12345", 0x1aca11fba0c62a025d804d2427a3026e20985c9ed1d03506b46a3c04fb58129f, 0),
            TldSldData("test2", 0x4e40f6e0b682912885261b48c6a9ba4f76aac8f74cb47354d0508b49a6c988d8, 0),
            TldSldData("vercel", 0xd0d40ba9106295eb8ca27fef46b62f28aa40437430d9800375a5593cd52ab902, 25),
            TldSldData("wallet", 0x1e3f482b3363eb4710dae2cb2183128e272eafbe137f686851c1caea32502230, 11),
            TldSldData("test4", 0x4e6651ae851ae03870ee069523fd893319ddfbec1a209387ad3e0d4eb7f477c7, 1)
        ];

        console.log("Current SLD counts on chain ID:", block.chainid);
        console.log("SLD Registration Manager:", config.sldRegistrationManagerProxy);

        SldRegistrationManager manager = SldRegistrationManager(config.sldRegistrationManagerProxy);

        for (uint256 i = 0; i < tldData.length; i++) {
            uint256 currentCount = manager.sldCountPerTld(tldData[i].namehash);
            console.log(
                string(
                    abi.encodePacked(
                        tldData[i].tldName, " (", vm.toString(tldData[i].namehash), "): ", vm.toString(currentCount)
                    )
                )
            );
        }
    }
}

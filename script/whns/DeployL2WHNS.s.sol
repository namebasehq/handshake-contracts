// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Script} from "forge-std/Script.sol";
import {WrappedHandshake} from "src/contracts/whns/whns-l2.sol";
import {console} from "forge-std/console.sol";

contract DeployWrappedHandshake is Script {
    // Constants for different chain IDs
    uint256 constant OPTIMISM_SEPOLIA_CHAIN_ID = 11155420;

    error UnsupportedChain(uint256 chainId);

    // forge script script/whns/DeployL2WHNS.s.sol:DeployWrappedHandshake --private-key $TESTING_PRIVATE_KEY --rpc-url $OPT_TEST_RPC --verify --etherscan-api-key $ETHERSCAN_API_KEY --legacy --via-ir --broadcast -vvv
    
    // https://sepolia-optimism.etherscan.io/tx/0xbef85bbe5239d8205415b1d2f2e7d6d01642b4131f88c9e10e35a73b54178b95
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("TESTING_PRIVATE_KEY");

        // Start broadcasting transactions using the deployer's private key
        vm.startBroadcast(deployerPrivateKey);

        // Set bridge and token addresses based on the chain ID in-line
        address L2_STANDARD_BRIDGE;
        address REMOTE_L1_TOKEN;

        if (block.chainid == OPTIMISM_SEPOLIA_CHAIN_ID) {
            L2_STANDARD_BRIDGE = 0x4200000000000000000000000000000000000010; // Optimism Sepolia L2 bridge address
            REMOTE_L1_TOKEN = 0x5c5ff04549b2722E53754DdfF97A743cA2b810ff;   // L1 token address on Sepolia
        } else {
            revert UnsupportedChain(block.chainid);
        }

        // Deploy the WrappedHandshake contract with the selected bridge and token addresses
        WrappedHandshake token = new WrappedHandshake(L2_STANDARD_BRIDGE, REMOTE_L1_TOKEN);

        // Log the deployed contract address
        console.log("WrappedHandshake deployed at:", address(token));

        // Stop broadcasting
        vm.stopBroadcast();
    }
}

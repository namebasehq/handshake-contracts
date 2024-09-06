// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Script} from "forge-std/Script.sol";
import {WrappedHandshake} from "src/contracts/whns/whns-l2.sol";
import {console} from "forge-std/console.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract DeployWrappedHandshake is Script {
    // Constants for different chain IDs
    uint256 constant OPTIMISM_SEPOLIA_CHAIN_ID = 11155420;
    uint256 constant OPTIMISM_MAINNET_CHAIN_ID = 10;


    error UnsupportedChain(uint256 chainId);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("TESTING_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        address L2_STANDARD_BRIDGE;
        address REMOTE_L1_TOKEN;
        address PROXY_OWNER;

        if (block.chainid == OPTIMISM_SEPOLIA_CHAIN_ID) {
            L2_STANDARD_BRIDGE = 0x4200000000000000000000000000000000000010; // Optimism Sepolia L2 bridge address
            REMOTE_L1_TOKEN = 0x5c5ff04549b2722E53754DdfF97A743cA2b810ff;   // L1 token address on Sepolia
            PROXY_OWNER = 0xeCb53F05b58AC856B2fb85925c691Fdef3a8CD9F;
        } 
        else if (block.chainid == OPTIMISM_MAINNET_CHAIN_ID) {
            REMOTE_L1_TOKEN = 0xA771b49064Da011DF051052848477f18DbA1d2Ac;
            L2_STANDARD_BRIDGE = 0x4200000000000000000000000000000000000010;
            PROXY_OWNER = 0xB5C63Fe9aCB6225b9547090B9f70eD63B7A1C99a;
        }
        else {
            revert UnsupportedChain(block.chainid);
        }

        // Step 1: Deploy the ProxyAdmin contract
        ProxyAdmin proxyAdmin = new ProxyAdmin();
        console.log("ProxyAdmin deployed at:", address(proxyAdmin));

        // Step 2: Deploy the WrappedHandshake implementation contract
        WrappedHandshake wrappedHandshakeImplementation = new WrappedHandshake();

        // Step 3: Deploy the TransparentUpgradeableProxy contract, managed by the ProxyAdmin
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(wrappedHandshakeImplementation), // WrappedHandshake implementation contract
            address(proxyAdmin),                     // ProxyAdmin contract to manage the proxy
            abi.encodeWithSelector(
                WrappedHandshake.initializeWrappedHandshake.selector,
                L2_STANDARD_BRIDGE,
                REMOTE_L1_TOKEN
            )
        );

        // Log the deployed proxy address
        console.log("WrappedHandshake proxy deployed at:", address(proxy));

        // Step 4: Set the proxy admin to the PROXY_OWNER (optional)
        proxyAdmin.transferOwnership(PROXY_OWNER);
        console.log("ProxyAdmin ownership transferred to:", PROXY_OWNER);

        // Stop broadcasting
        vm.stopBroadcast();
    }
}

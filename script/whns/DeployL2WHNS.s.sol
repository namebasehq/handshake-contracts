// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Script} from "forge-std/Script.sol";
import {WrappedHandshake} from "src/contracts/whns/whns-l2.sol";
import {console} from "forge-std/console.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

// forge script script/whns/DeployL2WHNS.s.sol:DeployWrappedHandshake --private-key $DEPLOYER_PRIVATE_KEY --rpc-url $OPT_RPC --verify --etherscan-api-key $ETHERSCAN_API_KEY --legacy -vvvv --via-ir --broadcast

contract DeployWrappedHandshake is Script {
    // Constants for different chain IDs
    uint256 constant OPTIMISM_SEPOLIA_CHAIN_ID = 11155420;
    uint256 constant OPTIMISM_MAINNET_CHAIN_ID = 10;

    error UnsupportedChain(uint256 chainId);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        address L2_STANDARD_BRIDGE;
        address REMOTE_L1_TOKEN;
        address OWNER;

        if (block.chainid == OPTIMISM_SEPOLIA_CHAIN_ID) {
            L2_STANDARD_BRIDGE = 0x4200000000000000000000000000000000000010; // Optimism Sepolia L2 bridge address
            REMOTE_L1_TOKEN = 0x60f8b64f4a246Acc35997c4bCa75c6e26D0465C2; // L1 token address on Sepolia
            OWNER = 0xeCb53F05b58AC856B2fb85925c691Fdef3a8CD9F;
        } else if (block.chainid == OPTIMISM_MAINNET_CHAIN_ID) {
            REMOTE_L1_TOKEN = address(0x439388F8B8Fb3C1bcDcB58b6d1a75607FEEaEF36);
            L2_STANDARD_BRIDGE = 0x4200000000000000000000000000000000000010;

        } else {
            revert UnsupportedChain(block.chainid);
        }

        WrappedHandshake whns = new WrappedHandshake(L2_STANDARD_BRIDGE, REMOTE_L1_TOKEN);


        vm.stopBroadcast();
    }
}

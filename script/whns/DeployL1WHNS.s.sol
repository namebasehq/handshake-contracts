// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Script} from "forge-std/Script.sol";
import {WrappedHandshake} from "src/contracts/whns/whns.sol";
import {console} from "forge-std/console.sol";


// this script is just for testing. 
// WHNS contract is already deployed on L1 at address 0xa771b49064da011df051052848477f18dba1d2ac
contract DeployWrappedHandshake is Script {
    uint256 constant SEPOLIA_CHAIN_ID = 11155111; // Sepolia chain ID
    uint8 constant DECIMALS = 6;

    error WrongChain(uint256 chainId);

    /*

        forge script script/whns/DeployL1WHNS.s.sol:DeployWrappedHandshake --private-key $DEPLOYER_PRIVATE_KEY --rpc-url $L1_RPC_URL --verify --etherscan-api-key $ETHERSCAN_L1_API_KEY --legacy --broadcast -vv
   
    */

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("TESTING_PRIVATE_KEY");
        
        // Start broadcasting transactions with the deployer's private key
        vm.startBroadcast(deployerPrivateKey);

        // Check the chain ID to ensure deployment is on Sepolia only
        if (block.chainid != SEPOLIA_CHAIN_ID) {
            revert WrongChain(block.chainid);
        }

        // Deploy the WrappedHandshake contract with 6 decimals
        WrappedHandshake token = new WrappedHandshake(DECIMALS);

        // Console log the deployed contract address
        console.log("L1 WrappedHandshake deployed at:", address(token));

        // Stop broadcasting transactions
        vm.stopBroadcast();
    }
}

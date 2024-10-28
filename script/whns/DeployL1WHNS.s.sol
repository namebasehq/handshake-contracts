// SPDX-License-Identifier: MIT
<<<<<<< HEAD
pragma solidity ~0.8.17;
=======
pragma solidity 0.8.17;
>>>>>>> main

import {Script} from "forge-std/Script.sol";
import {WrappedHandshake} from "src/contracts/whns/whns.sol";
import {console} from "forge-std/console.sol";

<<<<<<< HEAD
contract DeployWrappedHandshake is Script {
    uint256 constant SEPOLIA_CHAIN_ID = 11155111; // Sepolia chain ID
    uint8 constant DECIMALS = 18;
=======

// this script is just for testing. 
// WHNS contract is already deployed on L1 at address 0xa771b49064da011df051052848477f18dba1d2ac
contract DeployWrappedHandshake is Script {
    uint256 constant SEPOLIA_CHAIN_ID = 11155111; // Sepolia chain ID
    uint8 constant DECIMALS = 6;
>>>>>>> main

    error WrongChain(uint256 chainId);

    /*
<<<<<<< HEAD
        forge script script/whns/DeployL1WHNS.s.sol:DeployWrappedHandshake --private-key $DEPLOYER_PRIVATE_KEY --rpc-url https://mainnet.infura.io/v3/93545fc8220a4417b5ce6e9c1c646aa7 --verify --etherscan-api-key $ETHERSCAN_L1_API_KEY --legacy -vv --via-ir --broadcast 
    */

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        console.log(vm.addr(deployerPrivateKey));
        // Start broadcasting transactions with the deployer's private key
        vm.startBroadcast(deployerPrivateKey);

        console.log("Deployer address:", vm.addr(deployerPrivateKey));
=======

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
>>>>>>> main

        // Deploy the WrappedHandshake contract with 6 decimals
        WrappedHandshake token = new WrappedHandshake(DECIMALS);

<<<<<<< HEAD
        token.mint(msg.sender, 1e6 * 1e18);

        address newOwner = address(0xfF778cbb3f5192a3e848aA7D7dB2DeB2a4944821);

        token.transferOwnership(newOwner);

=======
>>>>>>> main
        // Console log the deployed contract address
        console.log("L1 WrappedHandshake deployed at:", address(token));

        // Stop broadcasting transactions
        vm.stopBroadcast();
    }
}

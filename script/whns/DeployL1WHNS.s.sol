// SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

import {Script} from "forge-std/Script.sol";
import {WrappedHandshake} from "src/contracts/whns/whns.sol";
import {console} from "forge-std/console.sol";

contract DeployWrappedHandshake is Script {
    uint256 constant SEPOLIA_CHAIN_ID = 11155111; // Sepolia chain ID
    uint8 constant DECIMALS = 18;

    error WrongChain(uint256 chainId);

    /*
        forge script script/whns/DeployL1WHNS.s.sol:DeployWrappedHandshake --private-key $DEPLOYER_PRIVATE_KEY --rpc-url https://mainnet.infura.io/v3/93545fc8220a4417b5ce6e9c1c646aa7 --verify --etherscan-api-key $ETHERSCAN_L1_API_KEY --legacy -vv --via-ir --broadcast 
    */

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        console.log(vm.addr(deployerPrivateKey));
        // Start broadcasting transactions with the deployer's private key
        vm.startBroadcast(deployerPrivateKey);

        console.log("Deployer address:", vm.addr(deployerPrivateKey));

        // Deploy the WrappedHandshake contract with 6 decimals
        WrappedHandshake token = new WrappedHandshake(DECIMALS);

        token.mint(msg.sender, 1e6 * 1e18);

        address newOwner = address(0xfF778cbb3f5192a3e848aA7D7dB2DeB2a4944821);

        token.transferOwnership(newOwner);

        // Console log the deployed contract address
        console.log("L1 WrappedHandshake deployed at:", address(token));

        // Stop broadcasting transactions
        vm.stopBroadcast();
    }
}

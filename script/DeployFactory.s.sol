// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import "contracts/Factory.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployFactoryScript is Script {
    // forge script script/DeployFactory.s.sol:DeployFactoryScript --private-key $DEPLOYER_PRIVATE_KEY --rpc-url $RPC_URL --broadcast -vv

    function setUp() public {}

    function run() public {
        // factory address: 0x399fd7143b07689e7014270720aa861e1e48ceda

        vm.startBroadcast(vm.envUint("GOERLI_DEPLOYER_PRIVATE_KEY"));

        Factory factory = new Factory();

        console.log("factory address:", address(factory));

        vm.stopBroadcast();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import "contracts/ccip/OffchainResolver.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployScript is Script {

    function setUp() public {}

    function run() public {

        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        string memory url = "http://localhost:3000/api/gateway/ccip?sender={sender}&data={data}";

        address[] memory signers = new address[](1);
        signers[0] = 0xdA29bd6a46B89Cc5a5a404663524132D2f7Df10f;

        OffchainResolver resolver = new OffchainResolver(
            url,
            signers
        );

        console.log("Deployed OffchainResolver at address: %s", address(resolver));

    }
}
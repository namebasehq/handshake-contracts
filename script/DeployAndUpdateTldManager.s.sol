// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";

import "contracts/HandshakeSld.sol";
import "test/upgrade-mocks/TldRegistrationManager.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

// forge script script/DeployAndUpdateTldManager.s.sol:DeployAndUpdateTldManager --private-key $DEPLOYER_PRIVATE_KEY --rpc-url $RPC_URL --broadcast -vv

contract DeployAndUpdateTldManager is Script {
    function setUp() public {}

    function run() public {
        address proxyAddress = address(0xB7f8BC63BbcaD18155201308C8f3540b07f84F5e);
        require(proxyAddress != address(0), "Proxy address is not set");
        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(payable(proxyAddress));

        //vm.startBroadcast(PUT_PRIVATE_KEY_HERE);

        MockTldClaimManager newImplementation = new MockTldClaimManager();

        //newImplementation.init();

        proxy.upgradeTo(address(newImplementation));
    }
}

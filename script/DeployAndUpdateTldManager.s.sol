// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";

import "contracts/HandshakeSld.sol";
import "test/upgrade-mocks/TldRegistrationManager.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployAndUpdateTldManager is Script {
    function setUp() public {}

    function run() public {
        address proxyAddress;

        require(proxyAddress != address(0), "Proxy address is not set");

        MockTldClaimManager newImplementation = new MockTldClaimManager();

        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(payable(proxyAddress));

        //newImplementation.init();

        proxy.upgradeTo(address(newImplementation));
    }
}

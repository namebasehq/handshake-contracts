// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";

import "contracts/HandshakeSld.sol";
import "test/upgrade-mocks/SldRegistrationManager.sol";
import "contracts/metadata/SldMetadataService.sol";
import "contracts/SldRegistrationManager.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployAndUpdateSldManager is Script {
    function setUp() public {}

    function run() public {
        TransparentUpgradeableProxy proxy;
    }
}

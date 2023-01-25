// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import "contracts/GlobalRegistrationRules.sol";
import "contracts/HandshakeSld.sol";
import "contracts/HandshakeTld.sol";
import "contracts/LabelValidator.sol";
import "contracts/metadata/SldMetadataService.sol";
import "contracts/metadata/TldMetadataService.sol";
import "contracts/SldCommitIntent.sol";
import "contracts/SldRegistrationManager.sol";
import "contracts/DefaultRegistrationStrategy.sol";
import "contracts/TldClaimManager.sol";
import "contracts/UsdPriceOracle.sol";
import "mocks/MockUsdOracle.sol";
import "contracts/resolvers/DefaultResolver.sol";
import "interfaces/IPriceOracle.sol";
import "test/mocks/TestingRegistrationStrategy.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract TestRegisterScript is Script {

    function setUp() public {}

    function run() public {

        vm.prank(0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC);

        SldRegistrationManager manager = SldRegistrationManager(0x610178dA211FEF7D417bC0e6FeD39F05609AD788);

        string memory label = "tetet"; 
        bytes32 parentNamehash = 0xe9242feec0bae9a1ed162b28c15e876119ba849b70a9e4023d1cb765abe0dd14;
        uint80 registrationLength = 365;
        manager.renewSld{value: 1.5 ether}(label, parentNamehash, registrationLength);

    }
}
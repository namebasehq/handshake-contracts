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
import "contracts/SldCommitIntentPassthrough.sol";
import "contracts/SldRegistrationManager.sol";
import "contracts/DefaultRegistrationStrategy.sol";
import "contracts/TldClaimManager.sol";
import "contracts/UsdPriceOracle.sol";
import "mocks/MockUsdOracle.sol";
import "contracts/resolvers/DefaultResolver.sol";
import "interfaces/IPriceOracle.sol";
import "test/mocks/TestingRegistrationStrategy.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployCommitIntentScript is Script {
    SldCommitIntentPassthrough commitIntent;
    LabelValidator labelValidator;
    IPriceOracle priceOracle;
    GlobalRegistrationRules globalRules;

    function run() public {
        SldRegistrationManager manager = SldRegistrationManager(
            0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6
        );

        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        // manager.updateSigner(0xdA29bd6a46B89Cc5a5a404663524132D2f7Df10f, true);
        bool valid = manager.ValidSigner(0xdA29bd6a46B89Cc5a5a404663524132D2f7Df10f);
        console.log('domain seperator');
        console.logBytes32(manager.DOMAIN_SEPARATOR());
        address valid2 = manager.checkSignatureValid(
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
        0x243c7f49b47b0c3ebec972b3b29671263571c473d9f9ad8aab143c745acde83f,
        28,
       0x899becb0c2609c60b75af6f1a13416ac2011bfa30bea3b7fcd47c9a83274fadf,
        0x1a7fa732b7bb9807462b5e4a7370c1bb9a2b7073e656e9f46fe098e622aaf8b2
        );
        console.log("valid: %s", valid2);

        manager.registerWithSignature(
        "sam",
        365,
        0xe9242feec0bae9a1ed162b28c15e876119ba849b70a9e4023d1cb765abe0dd14,
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
        28,
        0x899becb0c2609c60b75af6f1a13416ac2011bfa30bea3b7fcd47c9a83274fadf,
        0x1a7fa732b7bb9807462b5e4a7370c1bb9a2b7073e656e9f46fe098e622aaf8b2
    );
    }
}

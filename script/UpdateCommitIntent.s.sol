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
        TransparentUpgradeableProxy uups2 = TransparentUpgradeableProxy(
            payable(0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6)
        );

        commitIntent = new SldCommitIntentPassthrough();

        // address ownerWallet = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; //second wallet in anvil
        // address deployerWallet = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;

        vm.startBroadcast(0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d);
        SldRegistrationManager manager = new SldRegistrationManager();
        uups2.upgradeTo(address(manager));

        //vm.startBroadcast(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80);

        // vm.prank(ownerWallet);
        //SldRegistrationManager(address(uups2)).updateCommitIntent(commitIntent);
    }
}

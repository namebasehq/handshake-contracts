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
        address buyer = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        bytes32 subdomainHash = 0x243c7f49b47b0c3ebec972b3b29671263571c473d9f9ad8aab143c745acde83f;
        console.logBytes32(manager.getRegistrationHash(buyer, subdomainHash));
        address signer = ecrecover(
            manager.getRegistrationHash(buyer, subdomainHash),
            28,
            0xd2ba7c6f2eeece87d24fc06a1801460934db2d55fee70bfb18ac0e3cdac4bfa0,
            0x48fff59526011a6bb2ef3ed99230e47972b0636fb8a719ff733ccb2cd20164ae
            
        );

        console.log(signer);
        console.log(block.chainid);
        console.logBytes32(manager.DOMAIN_SEPARATOR());
    }
}

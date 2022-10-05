// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Script.sol";

import "contracts/GlobalRegistrationRules.sol";
import "contracts/HandshakeSld.sol";
import "contracts/HandshakeTld.sol";
import "contracts/LabelValidator.sol";
import "contracts/NftMetadataService.sol";
import "contracts/SldCommitIntent.sol";
import "contracts/SldRegistrationManager.sol";
import "contracts/TldClaimManager.sol";
import "contracts/UsdPriceOracle.sol";
import "proxy/DeployProxy.sol";

contract DeployScript is Script {
    DeployProxy proxyDeployer;

    LabelValidator labelValidator;
    SldCommitIntent commitIntent;
    UsdPriceOracle priceOracle;
    GlobalRegistrationRules globalRules;
    NftMetadataService metadata;

    function setUp() public {
        proxyDeployer = new DeployProxy();

        labelValidator = new LabelValidator();
        commitIntent = new SldCommitIntent();
        priceOracle = new UsdPriceOracle();
        globalRules = new GlobalRegistrationRules();
        metadata = new NftMetadataService("base_url/");
    }

    function run() public {
        vm.startBroadcast();

        address ownerWallet = address(0x1337);

        TldClaimManager tldClaimManager = new TldClaimManager(labelValidator);

        address tldClaimManagerProxyAddress = proxyDeployer.deployUupsProxy(
            address(tldClaimManager),
            ownerWallet,
            bytes("")
        );

        HandshakeTld tld = new HandshakeTld(TldClaimManager(tldClaimManagerProxyAddress), metadata);
        HandshakeSld sld = new HandshakeSld(tld, metadata);

        SldRegistrationManager registrationManager = new SldRegistrationManager(
            tld,
            sld,
            commitIntent,
            priceOracle,
            labelValidator,
            globalRules,
            ownerWallet
        );

        address registrationManagerProxyAddress = proxyDeployer.deployUupsProxy(
            address(registrationManager),
            ownerWallet,
            bytes("")
        );

        sld.setRegistrationManager(SldRegistrationManager(registrationManagerProxyAddress));

        //transfer ownership of ownable contracts
        tldClaimManager.transferOwnership(ownerWallet);
        registrationManager.transferOwnership(ownerWallet);
        sld.transferOwnership(ownerWallet);
        tld.transferOwnership(ownerWallet);
        commitIntent.transferOwnership(ownerWallet);

        vm.stopBroadcast();
    }
}

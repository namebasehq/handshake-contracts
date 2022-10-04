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

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        address ownerWallet = address(0x1337);

        LabelValidator labelValidator = new LabelValidator();

        NftMetadataService metadata = new NftMetadataService("base_url/");

        TldClaimManager tldClaimManager = new TldClaimManager(labelValidator);

        HandshakeTld tld = new HandshakeTld(tldClaimManager, metadata);
        HandshakeSld sld = new HandshakeSld(tld, metadata);

        SldCommitIntent commitIntent = new SldCommitIntent();
        UsdPriceOracle priceOracle = new UsdPriceOracle();
        GlobalRegistrationRules globalRules = new GlobalRegistrationRules();

        SldRegistrationManager registrationManager = new SldRegistrationManager(
            tld,
            sld,
            commitIntent,
            priceOracle,
            labelValidator,
            globalRules,
            ownerWallet
        );

        sld.setRegistrationManager(registrationManager);

        //transfer ownership of ownable contracts
        tldClaimManager.transferOwnership(ownerWallet);
        registrationManager.transferOwnership(ownerWallet);
        sld.transferOwnership(ownerWallet);
        tld.transferOwnership(ownerWallet);
        commitIntent.transferOwnership(ownerWallet);


        vm.stopBroadcast();
    }
}

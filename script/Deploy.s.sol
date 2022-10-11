// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

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

    function setUp() public {
        proxyDeployer = new DeployProxy();

        labelValidator = new LabelValidator();

        priceOracle = new UsdPriceOracle();
        globalRules = new GlobalRegistrationRules();
    }

    function run() public {
        /*
            Add the below to .env file.

            DEPLOYER_PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
            USER_PRIVATE_KEY=0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
            RPC_URL=http://localhost:8545

            These are just the default anvil private keys

        */

        //run `anvil` in seperate console window

        //run these commands to deploy to localhost blockchain
        //source .test-env
        //forge script script/Deploy.s.sol:DeployScript --private-key $PRIVATE_KEY --rpc-url $RPC_URL --broadcast -vv

        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        commitIntent = new SldCommitIntent();
        address ownerWallet = address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8); //second wallet in anvil

        TldClaimManager tldClaimManager = new TldClaimManager(labelValidator);

        address tldClaimManagerProxyAddress = proxyDeployer.deployUupsProxy(
            address(tldClaimManager),
            ownerWallet,
            bytes("")
        );

        HandshakeTld tld = new HandshakeTld(TldClaimManager(tldClaimManagerProxyAddress));
        HandshakeSld sld = new HandshakeSld(tld);

        NftMetadataService tldMetadata = new NftMetadataService(tld, "#000000");
        NftMetadataService sldMetadata = new NftMetadataService(sld, "#1f7bac");

        tld.setMetadataContract(tldMetadata);
        sld.setMetadataContract(sldMetadata);

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

        console.log("Sld address", address(sld));
        console.log("Tld address", address(tld));
        console.log("SldCommitIntent address", address(commitIntent));
        console.log(
            "SldRegistrationManager (proxy) address",
            address(registrationManagerProxyAddress)
        );
        console.log("TldClaimManager (proxy) address", address(tldClaimManagerProxyAddress));
        console.log("TldMetadata address", address(tldMetadata));
        console.log("SldMetadata address", address(sldMetadata));
        console.log("LabelValidator address", address(labelValidator));
        console.log("PriceOracle address", address(priceOracle));
        console.log("GlobalRegistrationRules address", address(globalRules));

        vm.stopBroadcast();
    }
}

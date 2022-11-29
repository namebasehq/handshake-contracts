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
import "contracts/DefaultRegistrationStrategy.sol";
import "contracts/TldClaimManager.sol";
import "contracts/UsdPriceOracle.sol";
import "mocks/MockUsdOracle.sol";
import "contracts/resolvers/DefaultResolver.sol";
import "interfaces/IPriceOracle.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployScript is Script {
    LabelValidator labelValidator;
    SldCommitIntent commitIntent;
    IPriceOracle priceOracle;
    GlobalRegistrationRules globalRules;

    function setUp() public {}

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
        //forge script script/Deploy.s.sol:DeployScript --private-key $DEPLOYER_PRIVATE_KEY --rpc-url $RPC_URL --broadcast -vv

        vm.startBroadcast(vm.envUint("NAMELESS_DEPLOYER_PRIVATE_KEY"));

        labelValidator = new LabelValidator();

        //priceOracle = new UsdPriceOracle();
        priceOracle = new MockUsdOracle(200000000000);
        globalRules = new GlobalRegistrationRules();

        commitIntent = new SldCommitIntent();
        address ownerWallet = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; //second wallet in anvil
        address deployerWallet = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;

        ownerWallet = 0x4559b1771b1d7C1846d91a91335273C3a28f9395;
        deployerWallet = 0x930efAd00Bbd2f22431eE3d9816D8246C0D45826;

        //TldClaimManager tldClaimManager = new TldClaimManager();

        TransparentUpgradeableProxy uups = new TransparentUpgradeableProxy(
            address(new TldClaimManager()),
            deployerWallet,
            bytes("")
        );

        HandshakeTld tld = new HandshakeTld(TldClaimManager(address(uups)));
        HandshakeSld sld = new HandshakeSld(tld);

        {

            NftMetadataService tldMetadata = new NftMetadataService(tld, "#000000");
            NftMetadataService sldMetadata = new NftMetadataService(sld, "#1f7bac");

            console.log("tld metadata", address(tldMetadata));
            console.log("sld metadata", address(sldMetadata));        
            
            tld.setMetadataContract(tldMetadata);
            sld.setMetadataContract(sldMetadata);
        }



        TransparentUpgradeableProxy uups2 = new TransparentUpgradeableProxy(
            address(new SldRegistrationManager()),
            deployerWallet,
            bytes("")
        );

        SldRegistrationManager(address(uups2)).init(
            tld,
            sld,
            commitIntent,
            priceOracle,
            labelValidator,
            globalRules,
            ownerWallet,
            ownerWallet
        );

        sld.setRegistrationManager(SldRegistrationManager(address(uups2)));

        DefaultRegistrationStrategy strategy = new DefaultRegistrationStrategy(tld);

        DefaultResolver resolver = new DefaultResolver(tld, sld);

        //transfer ownership of ownable contracts

        TldClaimManager(address(uups)).init(
            labelValidator,
            ownerWallet,
            tld,
            IResolver(address(resolver)),
            strategy
        );

        //registrationManager.transferOwnership(ownerWallet);
        sld.transferOwnership(ownerWallet);
        tld.transferOwnership(ownerWallet);
        commitIntent.transferOwnership(ownerWallet);

        delete ownerWallet;

        {
            NftMetadataService otherTldMetadata = new NftMetadataService(tld, "#d90e2d"); //red TLD
            NftMetadataService otherSldMetadata = new NftMetadataService(sld, "#950b96"); //purple SLD

            console.log("tld alternate metadata", address(otherTldMetadata));
            console.log("sld alternate metadata", address(otherSldMetadata));
        }

        vm.stopBroadcast();

        console.log("labelValidator", address(labelValidator));
        console.log("priceOracle", address(priceOracle));
        console.log("globalRules", address(globalRules));
        console.log("commitIntent", address(commitIntent));

        console.log("tldClaimManager", address(uups));
        console.log("SldRegistrationManager", address(uups2));
        console.log("tld", address(tld));
        console.log("sld", address(sld));
        console.log("defaultRegistrationStrategy", address(strategy));
        console.log("resolver", address(resolver));
    }
}

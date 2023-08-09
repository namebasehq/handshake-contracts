// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import "contracts/GlobalRegistrationRules.sol";
import "contracts/HandshakeSld.sol";
import "contracts/HandshakeTld.sol";
import "contracts/LabelValidator.sol";
import "contracts/metadata/GenericMetadata.sol";
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

contract DeployScript is Script {
    LabelValidator labelValidator;
    SldCommitIntent commitIntent;
    IPriceOracle priceOracle;
    GlobalRegistrationRules globalRules;

    HandshakeTld tld;
    HandshakeSld sld;

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

        address ownerWallet;
        address deployerWallet;

        {
            string memory baseUri;

            if (block.chainid == vm.envUint("NAMELESS_CHAIN_ID")) {
                ownerWallet = 0x4559b1771b1d7C1846d91a91335273C3a28f9395;
                deployerWallet = 0x930efAd00Bbd2f22431eE3d9816D8246C0D45826;
                vm.startBroadcast(vm.envUint("NAMELESS_DEPLOYER_PRIVATE_KEY"));
                priceOracle = new MockUsdOracle(200000000000);
            } else if (block.chainid == vm.envUint("GOERLI_CHAIN_ID") || block.chainid == 5) {
                ownerWallet = 0xeCb53F05b58AC856B2fb85925c691Fdef3a8CD9F;
                deployerWallet = 0x91769843CEc84Adcf7A48DF9DBd9694A39f44b42;
                vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));
                priceOracle = new UsdPriceOracle(0x57241A37733983F97C4Ab06448F244A1E0Ca0ba8);
                baseUri = "https://hnst.id/api/metadata/";
            } else {
                ownerWallet = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; //second wallet in anvil
                deployerWallet = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
                vm.startBroadcast(vm.envUint("LOCAL_PRIVATE_KEY"));
                priceOracle = new MockUsdOracle(200000000000);
                baseUri = "http://localhost:3000/api/metadata/";
            }

            tld = new HandshakeTld();
            sld = new HandshakeSld(tld);

            labelValidator = new LabelValidator();

            globalRules = new GlobalRegistrationRules();

            commitIntent = new SldCommitIntent();

            GenericMetadataService tldMetadata = new GenericMetadataService(sld, tld, baseUri);

            GenericMetadataService sldMetadata = new GenericMetadataService(sld, tld, baseUri);

            console.log("tld metadata", address(tldMetadata));
            console.log("sld metadata", address(sldMetadata));

            console.log("owner", tld.owner());

            tld.setMetadataContract(tldMetadata);
            sld.setMetadataContract(sldMetadata);
        }

        TransparentUpgradeableProxy uups2 = new TransparentUpgradeableProxy(
            address(new SldRegistrationManager()),
            deployerWallet,
            abi.encodeWithSelector(
                SldRegistrationManager.init.selector,
                tld,
                sld,
                commitIntent,
                priceOracle,
                labelValidator,
                globalRules,
                ownerWallet,
                ownerWallet
            )
        );

        DefaultRegistrationStrategy strategy = new DefaultRegistrationStrategy(
            SldRegistrationManager(address(uups2))
        );

        TransparentUpgradeableProxy uups = new TransparentUpgradeableProxy(
            address(new TldClaimManager()),
            deployerWallet,
            abi.encodeWithSelector(
                TldClaimManager.init.selector,
                labelValidator,
                ownerWallet,
                tld,
                strategy,
                priceOracle,
                100 ether,
                ownerWallet
            )
        );

        tld.setTldClaimManager(TldClaimManager(address(uups)));

        console.log("owner", SldRegistrationManager(address(uups2)).owner());
        console.log("msg.sender", msg.sender);
        SldRegistrationManager(address(uups2)).updateSigner(
            0xdA29bd6a46B89Cc5a5a404663524132D2f7Df10f,
            true
        );

        sld.setRegistrationManager(SldRegistrationManager(address(uups2)));

        DefaultResolver resolver = new DefaultResolver(tld, sld);

        //transfer ownership of ownable contracts
        sld.setDefaultResolver(IResolver(address(resolver)));
        tld.setDefaultResolver(IResolver(address(resolver)));

        //registrationManager.transferOwnership(ownerWallet);
        sld.transferOwnership(ownerWallet);
        tld.transferOwnership(ownerWallet);
        commitIntent.transferOwnership(ownerWallet);

        SldRegistrationManager(address(uups2)).updatePaymentPercent(5);

        delete ownerWallet;

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

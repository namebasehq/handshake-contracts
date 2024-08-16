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

    // https://docs.chain.link/data-feeds/price-feeds/addresses/?network=optimism
    address private constant ORACLE_ADDRESS = 0x13e3Ee699D1909E989722E753853AE30b17e08c5;

    // This will the the owner of the contracts that can run admin functions
    //address private constant CONTRACT_OWNER = 0xa90D04E5FaC9ba49520749711a12c3E5d0D9D6dA;

    // localhost
    address private constant CONTRACT_OWNER = 0xd3846142b49498A9FF08cf3CD8E1208669Fdbe0B;

    // This is the proxy owner for TldClaimManager and SldRegistrationManager. This address
    // must be different to the CONTRACT_OWNER as the proxy owner can only run admin functions
    // on the proxy contract and not the implementation contract.
    address private constant PROXY_OWNER = 0xfF778cbb3f5192a3e848aA7D7dB2DeB2a4944821;

    string private constant BASE_URI = "https://hnst.id/api/metadata/";

    function setUp() public {}

    function run() public {
        /*
            INSTRUCTIONS TO RUN LOCAL DEPLOYMENT
            -----------------------------------

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

        {
            vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));
            console.log("msg.sender", msg.sender);
            priceOracle = new UsdPriceOracle(ORACLE_ADDRESS);

            tld = new HandshakeTld();
            sld = new HandshakeSld(tld);

            labelValidator = new LabelValidator();

            globalRules = new GlobalRegistrationRules();

            commitIntent = new SldCommitIntent();

            GenericMetadataService genericMetadata = new GenericMetadataService(sld, tld, BASE_URI);

            console.log("tld metadata", address(genericMetadata));
            console.log("sld metadata", address(genericMetadata));

            tld.setMetadataContract(genericMetadata);
            sld.setMetadataContract(genericMetadata);
        }

        TransparentUpgradeableProxy uups2 = new TransparentUpgradeableProxy(
            address(new SldRegistrationManager()),
            PROXY_OWNER,
            abi.encodeWithSelector(
                SldRegistrationManager.init.selector,
                tld,
                sld,
                commitIntent,
                priceOracle,
                labelValidator,
                globalRules,
                CONTRACT_OWNER,
                CONTRACT_OWNER
            )
        );

        DefaultRegistrationStrategy strategy = new DefaultRegistrationStrategy(
            SldRegistrationManager(address(uups2))
        );

        TransparentUpgradeableProxy uups = new TransparentUpgradeableProxy(
            address(new TldClaimManager()),
            PROXY_OWNER,
            abi.encodeWithSelector(
                TldClaimManager.init.selector,
                labelValidator,
                CONTRACT_OWNER,
                tld,
                strategy,
                priceOracle,
                100 ether,
                CONTRACT_OWNER
            )
        );

        tld.setTldClaimManager(TldClaimManager(address(uups)));

        SldRegistrationManager(address(uups2)).updateSigner(
            0xdA29bd6a46B89Cc5a5a404663524132D2f7Df10f,
            true
        );

        sld.setRegistrationManager(SldRegistrationManager(address(uups2)));

        DefaultResolver resolver = new DefaultResolver(tld, sld);

        //transfer ownership of ownable contracts
        sld.setDefaultResolver(IResolver(address(resolver)));
        tld.setDefaultResolver(IResolver(address(resolver)));

        //registrationManager.transferOwnership(CONTRACT_OWNER);
        sld.transferOwnership(CONTRACT_OWNER);
        tld.transferOwnership(CONTRACT_OWNER);
        commitIntent.transferOwnership(CONTRACT_OWNER);

        SldRegistrationManager(address(uups2)).updatePaymentPercent(5);

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

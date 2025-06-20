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
    IPriceOracle priceOracle;

    // https://docs.chain.link/data-feeds/price-feeds/addresses/?network=optimism
    address private constant ORACLE_ADDRESS = 0x61Ec26aA57019C486B10502285c5A3D4A4750AD7;
    address private constant REGISTRATION_MANAGER = 0x529B2b5B576c27769Ae0aB811F1655012f756C00;

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
        //forge script script/DeployUsdOracle.s.sol:DeployScript --private-key $DEPLOYER_PRIVATE_KEY --rpc-url $OPT_TEST_RPC --broadcast -vv

        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));
        console.log("msg.sender", msg.sender);
        priceOracle = new UsdPriceOracle(ORACLE_ADDRESS);

        SldRegistrationManager manager = SldRegistrationManager(REGISTRATION_MANAGER);

        console.log("manager address: ", manager.owner());
        manager.updatePriceOracle(priceOracle);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";

import "contracts/HandshakeSld.sol";

import "contracts/metadata/SldMetadataService.sol";
import "contracts/SldRegistrationManager.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployMetadataScript is Script {
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

        if (block.chainid == vm.envUint("NAMELESS_CHAIN_ID")) {
            ownerWallet = 0x4559b1771b1d7C1846d91a91335273C3a28f9395;
            deployerWallet = 0x930efAd00Bbd2f22431eE3d9816D8246C0D45826;
            vm.startBroadcast(vm.envUint("NAMELESS_DEPLOYER_PRIVATE_KEY"));
        } else if (block.chainid == vm.envUint("GOERLI_CHAIN_ID")) {
            ownerWallet = 0xD3d701a25177767d9515D24bAe33F2Dc7A5D5EeF;
            deployerWallet = 0xBB21e0D5D40542db1410EE11B909B14A1e816d17;
            vm.startBroadcast(vm.envUint("GOERLI_DEPLOYER_PRIVATE_KEY"));
        } else {
            ownerWallet = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; //second wallet in anvil
            deployerWallet = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
            vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));
        }

        HandshakeSld sld = HandshakeSld(0xCe713c8321F83F4c6897894E3F571C5C23fee9f5);
        SldRegistrationManager registrationManager = SldRegistrationManager(
            0x538Cb06981b76E369786d6c1848550b01c808F89
        );

        // SldMetadataService metadataService = new SldMetadataService(sld,
        // registrationManager,
        // "#3773a1"
        // );

        // sld.setMetadataContract(metadataService);
    }
}

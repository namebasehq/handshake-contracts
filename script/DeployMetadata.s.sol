// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";

import "contracts/HandshakeSld.sol";

import "contracts/metadata/GenericMetadata.sol";
import "interfaces/IHandshakeSld.sol";
import "contracts/HandshakeTld.sol";
import "src/interfaces/ISldRegistrationManager.sol";
import "contracts/HandshakeSld.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployMetadataScript is Script {
    function setUp() public {}

    function run() public {
        //source .test-env
        //forge script script/DeployMetadata.s.sol:DeployMetadataScript --private-key $DEPLOYER_PRIVATE_KEY --rpc-url $RPC_URL --broadcast -vv

        HandshakeSld sld = HandshakeSld(0xb36387ab80007123Ef4da0d1677C22b94e00f60e);
        HandshakeTld tld = HandshakeTld(0xa2B3d56f91f1c4Aeff12aFD913904E851220B26C);

        vm.startBroadcast(vm.envUint("GOERLI_DEPLOYER_PRIVATE_KEY"));

        GenericMetadataService sldMD = new GenericMetadataService(sld, tld, "");

        console.log(msg.sender);
        sld.setMetadataContract(sldMD);
        //tld.setMetadataContract(sldMD);

        //string memory uri = HandshakeSld(address(sld)).tokenURI(0);
    }
}

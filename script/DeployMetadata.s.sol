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

        HandshakeSld sld = HandshakeSld(0x0165878A594ca255338adfa4d48449f69242Eb8F);
        HandshakeTld tld = HandshakeTld(0xa2B3d56f91f1c4Aeff12aFD913904E851220B26C);

        vm.startBroadcast(vm.envUint("GOERLI_DEPLOYER_PRIVATE_KEY"));

        // GenericMetadataService sldMD = new GenericMetadataService(sld, tld, "");

        // console.log(msg.sender);
        // sld.setMetadataContract(sldMD);

        string memory str = sld.name(
            0x243c7f49b47b0c3ebec972b3b29671263571c473d9f9ad8aab143c745acde83f
        );
        console.log(str);
        //tld.setMetadataContract(sldMD);

        //string memory uri = HandshakeSld(address(sld)).tokenURI(0);
    }
}

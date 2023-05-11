// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";

import "contracts/HandshakeSld.sol";

import "contracts/metadata/SldMetadataService.sol";
import "interfaces/IHandshakeSld.sol";
import "contracts/HandshakeNft.sol";
import "src/interfaces/ISldRegistrationManager.sol";
import "contracts/HandshakeSld.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployMetadataScript is Script {
    function setUp() public {}

    function run() public {
        //source .test-env
        //forge script script/DeployMetadata.s.sol:DeployMetadataScript --private-key $DEPLOYER_PRIVATE_KEY --rpc-url $RPC_URL --broadcast -vv

        IHandshakeSld sld = IHandshakeSld(0x0165878A594ca255338adfa4d48449f69242Eb8F);
        IHandshakeTld tld = IHandshakeTld(0x5FC8d32690cc91D4c39d9d3abcBD16989F875707);
        HandshakeNft nft = HandshakeNft(0x5FC8d32690cc91D4c39d9d3abcBD16989F875707);

        ISldRegistrationManager manager = ISldRegistrationManager(
            0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6
        );

        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        SldMetadataService sldMD = new SldMetadataService(sld, tld, manager, "#d90e2d");

        HandshakeSld(address(sld)).setMetadataContract(sldMD);

        //string memory uri = HandshakeSld(address(sld)).tokenURI(0);
    }
}

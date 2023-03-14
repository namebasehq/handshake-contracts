// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";

import "contracts/HandshakeSld.sol";

import "contracts/metadata/BlankSldMetadata.sol";
import "contracts/metadata/BlankTldMetadata.sol";
import "interfaces/IHandshakeSld.sol";
import "contracts/HandshakeNft.sol";
import "src/interfaces/ISldRegistrationManager.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployMetadataScript is Script {
    function setUp() public {}

    function run() public {
        //source .test-env
        //forge script script/DeployMetadata.s.sol:DeployMetadataScript --private-key $DEPLOYER_PRIVATE_KEY --rpc-url $RPC_URL --broadcast -vv

        IHandshakeSld sld = IHandshakeSld(0x5Dab68c75e44B50AE53126cd655Fa710E29E17E6);
        IHandshakeTld tld = IHandshakeTld(0xf6887A5Df4e6DB2016eCF79151ccD9807544fB88);
        HandshakeNft nft = HandshakeNft(0xf6887A5Df4e6DB2016eCF79151ccD9807544fB88);

        ISldRegistrationManager manager = ISldRegistrationManager(
            0xcB6Afb7Cd859503363bfb275B8d76Cef3d1e04a4
        );

        vm.startBroadcast(vm.envUint("GOERLI_DEPLOYER_PRIVATE_KEY"));

        BlankSldMetadataService sldMD = new BlankSldMetadataService(sld, tld, manager);
        BlankTldMetadataService tldMD = new BlankTldMetadataService(nft);

        console.log("Sld Metadata Address: ", address(sldMD));
        console.log("Tld Metadata Address: ", address(tldMD));
    }
}

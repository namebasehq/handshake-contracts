// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import "contracts/HandshakeTld.sol";
import "contracts/HandshakeSld.sol";
import "interfaces/IMetadataService.sol";
import "contracts/metadata/GenericMetadata.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract GetMetadataScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast(0xa5420fec30b713833569e9c4d85a57126535373a5423d8d81d379ded0d5c732f);

        //vm.startPrank(0xD3d701a25177767d9515D24bAe33F2Dc7A5D5EeF);

        // sld old: 0xE5B51B02E7FF920a243601980F206ae37e6095b3

        uint256 id = 87541375754719811489237015418166469271377514912956932100333180270417166731992;

        HandshakeSld sld = HandshakeSld(0xb36387ab80007123Ef4da0d1677C22b94e00f60e);
        HandshakeTld tld = HandshakeTld(0xa2B3d56f91f1c4Aeff12aFD913904E851220B26C);

        //nft = HandshakeNft(0x816402e0327735cbDdb7705Da94766e5B3a8A6fB);

        string memory baseUri = "https://hnst.id/api/metadata/";

        console.log("owner", sld.owner());

        // GenericMetadataService tldMetadata = new GenericMetadataService(sld, tld, baseUri);

        // sld.setMetadataContract(tldMetadata);
        // tld.setMetadataContract(tldMetadata);

        string memory uri = sld.tokenURI(id);
        console.log("uri:", uri);
    }
}

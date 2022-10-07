// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import "contracts/NftMetadataService.sol";
import "mocks/MockHandshakeNft.sol";
import {Namehash} from "utils/Namehash.sol";



contract TestHandshakeTld is Test {

    function setUp() public {

    }

    function testGetMetadata() public {

        MockHandshakeNft nft = new MockHandshakeNft();
        NftMetadataService metadata = new NftMetadataService(nft, "#000000");

        bytes32 namehash = Namehash.getTldNamehash("testing");

        string memory uri = metadata.tokenURI(namehash);
        console.log("tokenURI", uri);

    }

}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import "contracts/NftMetadataService.sol";
import "mocks/MockHandshakeNft.sol";
import {Namehash} from "utils/Namehash.sol";

contract TestHandshakeTld is Test {
    function setUp() public {}

    function testGetMetadataFromSld() public {
        MockHandshakeNft nft = new MockHandshakeNft();

        nft.setParent("domain");
        nft.setExpiry(1234567890);
        nft.setName("handshake.domain");
        NftMetadataService metadata = new NftMetadataService(nft, "#000000");

        bytes32 namehash = Namehash.getTldNamehash("testing");

        string memory uri = metadata.tokenURI(namehash);

        console.log("sld uri: ", uri);

        assertEq(
            keccak256(abi.encodePacked(uri)),
            0xc6a734fe6e9298c24cac3757b6babdd76ce5b09a406e17281f3322ed26df350a
        );

        /*
        data:application/json;utf8,
            {
                "name":"handshake.domain",
                "description":"Transferable Handshake Domain",
                "image":"data:image/svg+xml;utf8,
                    <svg width='600pt' height='600pt' version='1.0' viewBox='0 0 600 600'
                        xmlns='http://www.w3.org/2000/svg'>
                        <metadata>Namebase - Sam Ward</metadata>
                        <g transform='translate(0 725) scale(.1 -.1)' fill='#000000'>
                            <path d='m0 3605v-3605h3910 3910v3605 3605h-3910-3910v-3605zm1360 3380c0-2-102-186-227-407-291-517-283-502-283-510 0-5 9-17 20-28 19-19 33-20 454-20h434l81-141c45-78 81-143 81-145s-286-5-636-6l-637-3-214-400-166-2c-92-1-168 1-171 5-2 4 178 331 400 727 223 396 432 768 465 828l60 107h169c94 0 170-2 170-5zm170-186c58-93 80-138 76-153-3-11-70-136-149-276l-143-255-167-3c-92-1-167 0-167 4 0 12 455 814 462 814 4 0 43-59 88-131zm981-514c47-77 84-143 82-147-2-5-80-8-172-8h-167l-81 143c-44 78-79 145-76 150 2 4 77 6 166 5l161-3 87-140zm-433-27c108-189 107-152 11-327-72-131-85-150-96-136-27 38-153 263-153 275 0 11 160 310 166 310 1 0 34-55 72-122zm512-223c0-4-107-196-237-428s-328-586-441-787c-112-201-215-382-228-402l-24-38h-166c-145 0-165 2-160 15 3 9 59 111 124 228 66 117 176 314 246 438 69 124 126 232 126 240 0 38-12 39-461 39h-437l-86 148-85 147 637 5c350 3 638 6 639 8 0 1 20 37 43 80 24 42 72 130 107 195l64 117h170c93 0 169-2 169-5zm-1821-593 81-138-79-148c-43-81-83-152-87-156-5-5-45 54-92 135l-82 145 81 150c44 82 85 150 89 150s44-62 89-138zm927-207c-3-9-57-107-119-218-63-111-163-289-222-395-99-176-110-192-122-175-8 10-48 73-89 141l-76 124 143 256c78 141 147 263 152 270 7 9 54 12 174 12 144 0 164-2 159-15zm-1261-7c10-10 155-272 155-279 0-5-74-9-164-9h-164l-80 133c-45 73-84 139-87 147-4 13 19 15 166 13 94-1 173-3 174-5z'/>
                        </g>
                        <text x='60' y='500' fill='white' font-size='50' font='sans-serif'>handshake.domain</text>
                    </svg>",
                    "attributes":[
                        {
                            "trait_type":"parent name",
                            "value":"domain"
                        },
                        {
                            "trait_type":"expiry",
                            "display_type":"date",
                            "value":1234567890
                        }
                    ]
            }


        */
    }

    function testGetMetadataFromTld() public {
        MockHandshakeNft nft = new MockHandshakeNft();

        nft.setParent("");
        nft.setExpiry(0); //zero expiry we should get no expiry or parent name attributes
        nft.setName("domain");
        NftMetadataService metadata = new NftMetadataService(nft, "#cc0000");

        bytes32 namehash = Namehash.getTldNamehash("testing123");

        string memory uri = metadata.tokenURI(namehash);

        console.log("tld uri: ", uri);
        assertEq(
            keccak256(abi.encodePacked(uri)),
            0xd496b2654e3fb6c2627bbcfd565d5c932e6e528a4752f78eef4a108fd2810f26
        );

        /*
        data:application/json;utf8,
            {
                "name":"domain",
                "description":"Transferable Handshake Domain",
                "image":"data:image/svg+xml;utf8,
                    <svg width='600pt' height='600pt' version='1.0' viewBox='0 0 600 600'
                        xmlns='http://www.w3.org/2000/svg'>
                        <metadata>Namebase - Sam Ward</metadata>
                        <g transform='translate(0 725) scale(.1 -.1)' fill='#cc0000'>
                            <path d='m0 3605v-3605h3910 3910v3605 3605h-3910-3910v-3605zm1360 3380c0-2-102-186-227-407-291-517-283-502-283-510 0-5 9-17 20-28 19-19 33-20 454-20h434l81-141c45-78 81-143 81-145s-286-5-636-6l-637-3-214-400-166-2c-92-1-168 1-171 5-2 4 178 331 400 727 223 396 432 768 465 828l60 107h169c94 0 170-2 170-5zm170-186c58-93 80-138 76-153-3-11-70-136-149-276l-143-255-167-3c-92-1-167 0-167 4 0 12 455 814 462 814 4 0 43-59 88-131zm981-514c47-77 84-143 82-147-2-5-80-8-172-8h-167l-81 143c-44 78-79 145-76 150 2 4 77 6 166 5l161-3 87-140zm-433-27c108-189 107-152 11-327-72-131-85-150-96-136-27 38-153 263-153 275 0 11 160 310 166 310 1 0 34-55 72-122zm512-223c0-4-107-196-237-428s-328-586-441-787c-112-201-215-382-228-402l-24-38h-166c-145 0-165 2-160 15 3 9 59 111 124 228 66 117 176 314 246 438 69 124 126 232 126 240 0 38-12 39-461 39h-437l-86 148-85 147 637 5c350 3 638 6 639 8 0 1 20 37 43 80 24 42 72 130 107 195l64 117h170c93 0 169-2 169-5zm-1821-593 81-138-79-148c-43-81-83-152-87-156-5-5-45 54-92 135l-82 145 81 150c44 82 85 150 89 150s44-62 89-138zm927-207c-3-9-57-107-119-218-63-111-163-289-222-395-99-176-110-192-122-175-8 10-48 73-89 141l-76 124 143 256c78 141 147 263 152 270 7 9 54 12 174 12 144 0 164-2 159-15zm-1261-7c10-10 155-272 155-279 0-5-74-9-164-9h-164l-80 133c-45 73-84 139-87 147-4 13 19 15 166 13 94-1 173-3 174-5z'/>
                        </g>
                        <text x='60' y='500' fill='white' font-size='50' font='sans-serif'>domain</text>
                    </svg>
                ",
                "attributes":[                   
                ]
            }

        */
    }
}

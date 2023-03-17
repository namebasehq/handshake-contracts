// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

import "test/mocks/TestResolvers.sol";
import "test/mocks/MockHandshakeNft.sol";

contract TestContentHashResolver is Test {
    TestingContentHashResolver resolver;
    MockHandshakeNft tld;
    MockHandshakeNft sld;

    function setUp() public {
        tld = new MockHandshakeNft();
        sld = new MockHandshakeNft();

        resolver = new TestingContentHashResolver(tld, sld);
    }

    function testSetContentHashFromOwner_success() public {
        address owner = address(0x99887766);
        uint256 id = 696969;
        vm.prank(owner);
        sld.mint(owner, id);

        string memory contentHash = "this is content hash";

        vm.prank(owner);
        resolver.setContentHash(bytes32(id), bytes(contentHash));

        assertEq(
            string(resolver.contenthash(bytes32(id))),
            contentHash,
            "contenthash does not match"
        );
    }

    function testSetContentHashFromApprovedAddress_success() public {
        address owner = address(0x99887766);
        address approved = address(0x123456);

        uint256 id = 696969;
        vm.prank(owner);
        sld.mint(owner, id);

        vm.prank(owner);
        sld.setApprovalForAll(approved, true);

        string memory contentHash = "this is content hash";

        vm.prank(approved);
        resolver.setContentHash(bytes32(id), bytes(contentHash));

        assertEq(
            string(resolver.contenthash(bytes32(id))),
            contentHash,
            "contenthash does not match"
        );
    }

    function testSetContentHashFromNotApprovedAddress_fail() public {
        address owner = address(0x99887766);
        address notApproved = address(0x123456);

        uint256 id = 696969;
        vm.prank(owner);
        sld.mint(owner, id);

        string memory contentHash = "this is content hash";

        vm.expectRevert(BaseResolver.NotApprovedOrOwner.selector);
        vm.prank(notApproved);
        resolver.setContentHash(bytes32(id), bytes(contentHash));
    }

    function testSetContentHashIncrementVersionsCheckContentHashIsBlank() public {
        address owner = address(0x99887766);
        uint256 id = 696969;
        vm.prank(owner);
        sld.mint(owner, id);

        string memory contentHash = "this is content hash";

        vm.prank(owner);
        resolver.setContentHash(bytes32(id), bytes(contentHash));

        assertEq(
            string(resolver.contenthash(bytes32(id))),
            contentHash,
            "contenthash does not match"
        );

        vm.prank(owner);
        resolver.incrementVersion(bytes32(id));

        assertEq(string(resolver.contenthash(bytes32(id))), "", "contenthash does not match");
    }
}

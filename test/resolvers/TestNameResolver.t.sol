// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

import "test/mocks/TestResolvers.sol";
import "test/mocks/MockHandshakeNft.sol";

contract TestNameResolver is Test {
    TestingNameResolver resolver;
    MockHandshakeNft tld;
    MockHandshakeNft sld;

    function setUp() public {
        tld = new MockHandshakeNft();
        sld = new MockHandshakeNft();

        resolver = new TestingNameResolver(tld, sld);
    }

    function testGetSldName() public {
        address owner = address(0x99887766);
        uint256 id = 696969;
        bytes32 node = bytes32(id);
        string memory value = "MyName.domain";

        sld.mint(owner, id);

        sld.setName(node, value);

        assertEq(resolver.name(node), value);
    }

    function testGetTldName() public {
        address owner = address(0x99887766);
        uint256 id = 696969;
        bytes32 node = bytes32(id);
        string memory value = "MyName";

        tld.mint(owner, id);

        tld.setName(node, value);

        assertEq(resolver.name(node), value);
    }

    function testNameDoesNotExist() public {
        address owner = address(0x99887766);
        uint256 id = 696969;
        uint256 id_not_exist = 42069;
        bytes32 node = bytes32(id);
        bytes32 node2 = bytes32(id_not_exist);
        string memory value = "MyName";

        tld.mint(owner, id);

        tld.setName(node, value);

        vm.expectRevert("id does not exist");
        resolver.name(node2);
    }
}

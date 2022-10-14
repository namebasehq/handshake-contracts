// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import "test/mocks/TestResolvers.sol";
import "test/mocks/MockHandshakeNft.sol";

contract TestInterfaceResolver is Test {
    TestingInterfaceResolver resolver;
    MockHandshakeNft tld;
    MockHandshakeNft sld;

    function setUp() public {
        tld = new MockHandshakeNft();
        sld = new MockHandshakeNft();

        resolver = new TestingInterfaceResolver(tld, sld);
    }

    function testSetInterfaceFromOwner_success() public {
        address owner = address(0x99887766);
        address implementer = address(0x225588);
        uint256 id = 696969;
        vm.prank(owner);
        sld.mint(owner, id);

        bytes32 node = bytes32(id);

        bytes4 selector = bytes4(hex"abcdef12");

        vm.prank(owner);
        resolver.setInterface(node, selector, implementer);

        assertEq(resolver.interfaceImplementer(node, selector), implementer);
    }

    function testSetInterfaceFromApprovedAddress_success() public {
        address owner = address(0x99887766);
        address implementer = address(0x225588);
        address approved = address(0x99221144);

        uint256 id = 696969;
        vm.prank(owner);
        sld.mint(owner, id);

        bytes32 node = bytes32(id);

        bytes4 selector = bytes4(hex"abcdef12");

        vm.prank(owner);
        sld.setApprovalForAll(approved, true);

        vm.prank(approved);
        resolver.setInterface(node, selector, implementer);

        assertEq(resolver.interfaceImplementer(node, selector), implementer);
    }

    function testSetInterfaceFromNotApprovedAddress_fail() public {
        address owner = address(0x99887766);
        address implementer = address(0x225588);
        address not_approved = address(0x99221144);

        uint256 id = 696969;
        vm.prank(owner);
        sld.mint(owner, id);

        bytes32 node = bytes32(id);

        bytes4 selector = bytes4(hex"abcdef12");

        vm.expectRevert("not authorised or owner");
        vm.prank(not_approved);
        resolver.setInterface(node, selector, implementer);

        assertEq(resolver.interfaceImplementer(node, selector), address(0));
    }

    function testSetInterfaceIncrementVersionShouldClear_success() public {
        address owner = address(0x99887766);
        address implementer = address(0x225588);
        uint256 id = 696969;
        vm.prank(owner);
        sld.mint(owner, id);

        bytes32 node = bytes32(id);

        bytes4 selector = bytes4(hex"abcdef12");
        bytes4 selector2 = bytes4(hex"dcbaef12");
        vm.startPrank(owner);
        resolver.setInterface(node, selector, implementer);
        resolver.setInterface(node, selector2, implementer);

        assertEq(resolver.interfaceImplementer(node, selector), implementer);
        assertEq(resolver.interfaceImplementer(node, selector2), implementer);

        resolver.incrementVersion(node);

        assertEq(resolver.interfaceImplementer(node, selector), address(0));
        assertEq(resolver.interfaceImplementer(node, selector2), address(0));
    }
}

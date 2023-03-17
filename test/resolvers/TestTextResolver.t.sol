// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

import "test/mocks/TestResolvers.sol";
import "test/mocks/MockHandshakeNft.sol";

contract TestTextResolver is Test {
    TestingTextResolver resolver;
    MockHandshakeNft tld;
    MockHandshakeNft sld;

    function setUp() public {
        tld = new MockHandshakeNft();
        sld = new MockHandshakeNft();

        resolver = new TestingTextResolver(tld, sld);
    }

    function testSetTextFromOwner_success() public {
        address owner = address(0x99887766);
        uint256 id = 696969;
        bytes32 node = bytes32(id);

        vm.prank(owner);
        sld.mint(owner, id);

        string memory key = "key";
        string memory value = "value";

        vm.prank(owner);
        resolver.setText(node, key, value);

        assertEq(resolver.text(node, key), value);
    }

    function testSetTextFromApprovedAddress_success() public {
        address owner = address(0x99887766);
        address approved = address(0x919191);

        uint256 id = 696969;
        bytes32 node = bytes32(id);

        vm.prank(owner);
        sld.mint(owner, id);

        string memory key = "key";
        string memory value = "value";

        vm.prank(owner);
        sld.setApprovalForAll(approved, true);

        vm.prank(approved);
        resolver.setText(node, key, value);

        assertEq(resolver.text(node, key), value);
    }

    function testSetTextFromNotApprovedAddress_fail() public {
        address owner = address(0x99887766);
        address not_approved = address(0x5555555555);
        uint256 id = 696969;
        bytes32 node = bytes32(id);

        vm.prank(owner);
        sld.mint(owner, id);

        string memory key = "key";
        string memory value = "value";

        //
        vm.startPrank(not_approved);
        vm.expectRevert(BaseResolver.NotApprovedOrOwner.selector);
        resolver.setText(node, key, value);

        //should be blank
        assertEq(resolver.text(node, key), "");
    }

    function testSetMultipleTextFromOwnerOverwriteValue_success() public {
        address owner = address(0x99887766);
        uint256 id = 696969;
        uint256 id2 = 696969420;
        bytes32 node = bytes32(id);
        bytes32 node2 = bytes32(id2);

        vm.startPrank(owner);
        sld.mint(owner, id);
        sld.mint(owner, id2);

        string memory key = "key";
        string memory value = "value";

        string memory key2 = "key2";
        string memory value2 = "value2";

        string memory key3 = "key3";
        string memory value3 = "value3";

        resolver.setText(node, key, value);
        resolver.setText(node, key2, value2);
        resolver.setText(node, key3, value3);

        assertEq(resolver.text(node, key), value);
        assertEq(resolver.text(node, key2), value2);
        assertEq(resolver.text(node, key3), value3);

        assertEq(resolver.text(node2, key), "");
        assertEq(resolver.text(node2, key2), "");
        assertEq(resolver.text(node2, key3), "");

        string memory alternate_value = "blaaaaah";
        resolver.setText(node, key2, alternate_value);

        assertEq(resolver.text(node, key), value);
        assertEq(resolver.text(node, key2), alternate_value);
        assertEq(resolver.text(node, key3), value3);
    }

    function testSetTextIncrementVersionsCheckTextIsReset() public {
        address owner = address(0x99887766);
        uint256 id = 696969;
        uint256 id2 = 696969420;
        bytes32 node = bytes32(id);
        bytes32 node2 = bytes32(id2);

        vm.startPrank(owner);
        sld.mint(owner, id);
        sld.mint(owner, id2);

        string memory key = "key";
        string memory value = "value";

        string memory key2 = "key2";
        string memory value2 = "value2";

        string memory key3 = "key3";
        string memory value3 = "value3";

        resolver.setText(node, key, value);
        resolver.setText(node, key2, value2);
        resolver.setText(node, key3, value3);

        resolver.setText(node2, key, value);
        resolver.setText(node2, key2, value2);
        resolver.setText(node2, key3, value3);

        assertEq(resolver.text(node, key), value);
        assertEq(resolver.text(node, key2), value2);
        assertEq(resolver.text(node, key3), value3);

        assertEq(resolver.text(node2, key), value);
        assertEq(resolver.text(node2, key2), value2);
        assertEq(resolver.text(node2, key3), value3);

        resolver.incrementVersion(node);

        assertEq(resolver.text(node, key), "");
        assertEq(resolver.text(node, key2), "");
        assertEq(resolver.text(node, key3), "");

        assertEq(resolver.text(node2, key), value);
        assertEq(resolver.text(node2, key2), value2);
        assertEq(resolver.text(node2, key3), value3);
    }
}

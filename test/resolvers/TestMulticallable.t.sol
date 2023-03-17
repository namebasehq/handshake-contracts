// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

import "contracts/resolvers/DefaultResolver.sol";
import "test/mocks/MockHandshakeNft.sol";

contract TestMulticallable is Test {
    DefaultResolver resolver;
    MockHandshakeNft tld;
    MockHandshakeNft sld;

    function setUp() public {
        tld = new MockHandshakeNft();
        sld = new MockHandshakeNft();

        resolver = new DefaultResolver(tld, sld);
    }

    bytes[] testArray;

    function testCallSingleFunction() public {
        address owner = address(0x99887766);
        uint256 id = 696969;
        bytes32 node = bytes32(id);

        vm.prank(owner);
        sld.mint(owner, id);

        string memory key = "key";
        string memory value = "value";

        bytes4 sig = bytes4(keccak256("setText(bytes32,string,string)"));

        testArray.push(abi.encodeWithSelector(sig, node, key, value));

        vm.prank(owner);
        resolver.multicall(testArray);

        assertEq(resolver.text(node, key), value);
    }

    function testCallMultipleFunction() public {
        address owner = address(0x99887766);
        uint256 id = 696969;
        bytes32 node = bytes32(id);

        vm.prank(owner);
        sld.mint(owner, id);

        string memory key = "key";
        string memory value = "value";

        string memory key2 = "key2";
        string memory value2 = "value2";

        string memory key3 = "key3";
        string memory value3 = "value3";

        bytes4 sig = bytes4(keccak256("setText(bytes32,string,string)"));

        testArray.push(abi.encodeWithSelector(sig, node, key, value));
        testArray.push(abi.encodeWithSelector(sig, node, key2, value2));
        testArray.push(abi.encodeWithSelector(sig, node, key3, value3));

        vm.prank(owner);
        resolver.multicall(testArray);

        assertEq(resolver.text(node, key), value);
        assertEq(resolver.text(node, key2), value2);
        assertEq(resolver.text(node, key3), value3);
    }

    function testCallMultipleFunctionFromApprovedAddress() public {
        address owner = address(0x99887766);
        address approved = address(0x112233445566);

        uint256 id = 696969;
        bytes32 node = bytes32(id);

        sld.mint(owner, id);

        string memory key = "key";
        string memory value = "value";

        string memory key2 = "key2";
        string memory value2 = "value2";

        string memory key3 = "key3";
        string memory value3 = "value3";

        bytes4 sig = bytes4(keccak256("setText(bytes32,string,string)"));

        testArray.push(abi.encodeWithSelector(sig, node, key, value));
        testArray.push(abi.encodeWithSelector(sig, node, key2, value2));
        testArray.push(abi.encodeWithSelector(sig, node, key3, value3));

        vm.prank(owner);
        sld.setApprovalForAll(approved, true);

        vm.prank(approved);
        resolver.multicall(testArray);

        assertEq(resolver.text(node, key), value);
        assertEq(resolver.text(node, key2), value2);
        assertEq(resolver.text(node, key3), value3);
    }

    function testReadMultipleFunction() public {
        address owner = address(0x99887766);

        uint256 id = 696969;
        bytes32 node = bytes32(id);

        sld.mint(owner, id);

        string memory key = "key";
        string memory value = "value";

        string memory key2 = "key2";
        string memory value2 = "value2";

        string memory key3 = "key3";
        string memory value3 = "value3";

        bytes4 sig = bytes4(keccak256("text(bytes32,string)"));

        testArray.push(abi.encodeWithSelector(sig, node, key));
        testArray.push(abi.encodeWithSelector(sig, node, key2));
        testArray.push(abi.encodeWithSelector(sig, node, key3));

        vm.startPrank(owner);
        resolver.setText(node, key, value);
        resolver.setText(node, key2, value2);
        resolver.setText(node, key3, value3);

        bytes[] memory data = resolver.multicall(testArray);

        string memory s1 = abi.decode(data[0], (string));
        string memory s2 = abi.decode(data[1], (string));
        string memory s3 = abi.decode(data[2], (string));

        assertEq(s1, value);
        assertEq(s2, value2);
        assertEq(s3, value3);
    }

    bytes[] testArray2;

    function testCallMultipleFunctionNotAuthorised_fail() public {
        address owner = address(0x99887766);
        address owner2 = address(0x123456789);
        uint256 id = 696969;
        uint256 id2 = 5555885522;
        bytes32 node = bytes32(id);
        bytes32 node2 = bytes32(id2);

        sld.mint(owner, id);
        sld.mint(owner2, id2);

        string memory key = "key";
        string memory value = "value";

        string memory key2 = "key2";
        string memory value2 = "value2";

        string memory key3 = "key3";
        string memory value3 = "value3";

        bytes4 sig = bytes4(keccak256("setText(bytes32,string,string)"));

        testArray.push(abi.encodeWithSelector(sig, node, key, value));
        testArray.push(abi.encodeWithSelector(sig, node, key2, value2));
        testArray.push(abi.encodeWithSelector(sig, node, key3, value3));
        testArray.push(abi.encodeWithSelector(sig, node2, key, value));

        vm.expectRevert(Multicallable.NamehashMismatch.selector);
        vm.startPrank(owner);
        resolver.multicallWithNodeCheck(node, testArray);

        vm.expectRevert();
        resolver.multicall(testArray);

        assertEq(resolver.text(node, key), "");
        assertEq(resolver.text(node, key2), "");
        assertEq(resolver.text(node, key3), "");
        assertEq(resolver.text(node2, key), "");

        testArray2.push(abi.encodeWithSelector(sig, node, key, value));
        testArray2.push(abi.encodeWithSelector(sig, node, key2, value2));
        testArray2.push(abi.encodeWithSelector(sig, node, key3, value3));

        resolver.multicall(testArray2);

        assertEq(resolver.text(node, key), value);
        assertEq(resolver.text(node, key2), value2);
        assertEq(resolver.text(node, key3), value3);
        assertEq(resolver.text(node2, key), "");
    }
}

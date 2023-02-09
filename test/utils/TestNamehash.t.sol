// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import {Namehash} from "utils/Namehash.sol";

import "utils/RRUtils.sol";
import "utils/BytesUtils.sol";

contract TestNamehash is Test {
    function testNamehashFromFullDomain_tld() public {
        string memory domain = "tld";
        bytes32 node;

        node = keccak256(abi.encodePacked(node, keccak256(abi.encodePacked(domain))));

        assertEq(Namehash.getDomainNamehash(domain), node, "Namehash should match");
    }

    function testNamehashFromFullDomain_sld() public {
        string memory domain = "sld.tld";
        bytes32 node;

        node = keccak256(abi.encodePacked(node, keccak256(abi.encodePacked("tld"))));
        node = keccak256(abi.encodePacked(node, keccak256(abi.encodePacked("sld"))));

        assertEq(Namehash.getDomainNamehash(domain), node, "Namehash should match");
    }
}

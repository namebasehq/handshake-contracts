// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

import "src/contracts/Resolver.sol";


contract ResolverTests is Test {

    address constant SldContract = address(0x336699);
    address constant TldContract = address(0x996633);

    Resolver resolver;

    function setUp() public {
        resolver = new Resolver(SldContract, TldContract);
    }
    
    function testUpdateTextFromAuthorisedAddress() public {
        bytes32 namehash = bytes32(uint256(0x1337));
        string memory key = "key1";
        string memory value = "value1";

        vm.startPrank(SldContract);
        resolver.setText(namehash, key, value);
        assertEq(value, resolver.text(namehash, key));
        vm.stopPrank();

        //change value
        value = "value2";

        vm.startPrank(TldContract);
        resolver.setText(namehash, key, value);
        assertEq(value, resolver.text(namehash, key));
        vm.stopPrank();
    }

        function testUpdateContentHashFromAuthorisedAddress() public {
        bytes32 namehash = bytes32(uint256(0x1337));

        bytes memory value = bytes("value123");

        vm.startPrank(SldContract);
        resolver.setContentHash(namehash, value);
        assertEq(value, resolver.contenthash(namehash));
        vm.stopPrank();

        //change value
        value = bytes("value234");

        vm.startPrank(TldContract);
        resolver.setContentHash(namehash, value);
        assertEq(value, resolver.contenthash(namehash));
        vm.stopPrank();
    }

    function testUpdateDnsRecordFromAuthorisedAddress() public {

        assertTrue(false, "not implemented");

    }

        function testUpdateNameFromAuthorisedAddress() public {
        bytes32 namehash = bytes32(uint256(0x1337));

        string memory value = "name1";

        vm.startPrank(SldContract);
        resolver.setName(namehash, value);
        assertEq(value, resolver.name(namehash));
        vm.stopPrank();

        //change value
        value = "value2";

        vm.startPrank(TldContract);
        resolver.setName(namehash, value);
        assertEq(value, resolver.name(namehash));
        vm.stopPrank();
    }

    function testUpdatePublicKeyFromAuthorisedAddress() public {
        //need some clarification on this one
        assertTrue(false, "not implemented");
    }

    function testUpdateAddressFromAuthorisedAddress () public {
        //need to understand what addreses we storing here.. do we do something like ENS where we can
        //store multi-chain, or just ETH address(s)
        assertTrue(false, "not implemented");
    }



}
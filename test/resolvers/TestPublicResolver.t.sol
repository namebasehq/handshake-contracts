// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

import "contracts/PublicResolver.sol";

contract TestPublicResolver is Test {
    address constant tldContract = address(0x996633);
    address constant sldContract = address(0x336699);

    PublicResolver resolver;

    function setUp() public {
        resolver = new PublicResolver(tldContract, sldContract);
    }

    function testUpdateTextFromAuthorisedAddressSLD() public {
        bytes32 namehash = bytes32(uint256(0x1337));
        string memory key = "key1";
        string memory value = "value1";

        vm.startPrank(sldContract);
        resolver.setText(namehash, key, value);
        assertEq(value, resolver.text(namehash, key));
        vm.stopPrank();
    }

    function testUpdateTextFromAuthorisedAddressTLD() public {
        bytes32 namehash = bytes32(uint256(0x1337));
        string memory key = "key1";
        string memory value = "value1";

        vm.startPrank(tldContract);
        resolver.setText(namehash, key, value);
        assertEq(value, resolver.text(namehash, key));
        vm.stopPrank();
    }

    function testUpdateContentHashFromAuthorisedAddress() public {
        bytes32 namehash = bytes32(uint256(0x1337));

        bytes memory value = bytes("value123");

        vm.startPrank(sldContract);
        resolver.setContenthash(namehash, value);
        assertEq(value, resolver.contenthash(namehash));
        vm.stopPrank();

        //change value
        value = bytes("value234");

        vm.startPrank(tldContract);
        resolver.setContenthash(namehash, value);
        assertEq(value, resolver.contenthash(namehash));
        vm.stopPrank();
    }

    function testUpdateNameFromAuthorisedAddress() public {
        bytes32 namehash = bytes32(uint256(0x1337));

        string memory value = "name1";

        vm.startPrank(sldContract);
        resolver.setName(namehash, value);
        assertEq(value, resolver.name(namehash));
        vm.stopPrank();

        //change value
        value = "value2";

        vm.startPrank(tldContract);
        resolver.setName(namehash, value);
        assertEq(value, resolver.name(namehash));
        vm.stopPrank();
    }

    function testUpdateDnsRecordFromAuthorisedAddress() public {
        assertTrue(false, "not implemented");
    }

    function testUpdatePublicKeyFromAuthorisedAddress() public {
        //need some clarification on this one
        assertTrue(false, "not implemented");
    }

    function testUpdateAddressFromAuthorisedAddress() public {
        //need to understand what addreses we storing here.. do we do something like ENS where we can
        //store multi-chain, or just ETH address(s)
        assertTrue(false, "not implemented");
    }
}

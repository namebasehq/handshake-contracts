// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

import "src/contracts/ccip/OffchainResolver.sol";

contract TestOffchainResolver is Test {
    OffchainResolver resolver;

    function setUp() public {
        setUpConstructorWithData();
    }

    function testResolverSetupFromConstructor() public {
        assertTrue(resolver.signers(address(0x1337)));
        assertEq(resolver.url(), "https:/testing.com/{sender}/{data}.json");
    }

    function testSetUrlFromOwner() public {
        string memory newUrl = "https://this_is_a_new_url.com/{sender}/{data}.json";
        resolver.updateUrl(newUrl);
        assertEq(resolver.url(), newUrl);
    }

    function testSetUrlFromNonOwner_fail() public {
        string memory newUrl = "https://this_is_a_new_url.com/{sender}/{data}.json";

        vm.prank(address(0x44));
        vm.expectRevert("Ownable: caller is not the owner");
        resolver.updateUrl(newUrl);
    }

    function testSetSignerFromOwner() public {
        address[] memory signers = new address[](1);
        signers[0] = address(0x69420);

        bool[] memory canSign = new bool[](1);
        canSign[0] = true;

        resolver.updateSigners(signers, canSign);

        assertTrue(resolver.signers(address(0x1337)));
        assertTrue(resolver.signers(address(0x69420)));

        assertFalse(resolver.signers(address(0x42069)));
    }

    function testSetSignerFromNonOwner_fail() public {
        address[] memory signers = new address[](1);
        signers[0] = address(0x69420);

        bool[] memory canSign = new bool[](1);
        canSign[0] = true;

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(0x44));
        resolver.updateSigners(signers, canSign);

        assertTrue(resolver.signers(address(0x1337)));
        assertFalse(resolver.signers(address(0x69420)));
    }

    function testRemoveSigner() public {
        address[] memory signers = new address[](1);
        signers[0] = address(0x1337);

        bool[] memory canSign = new bool[](1);
        canSign[0] = false;

        resolver.updateSigners(signers, canSign);

        assertFalse(resolver.signers(address(0x1337)));
        assertFalse(resolver.signers(address(0x69420)));
    }

    function setUpConstructorWithData() private {
        address[] memory signers = new address[](1);
        signers[0] = address(0x1337);
        string memory url = "https:/testing.com/{sender}/{data}.json";

        resolver = new OffchainResolver(url, signers, address(0), address(0));
    }
}

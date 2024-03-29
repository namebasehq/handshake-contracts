// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

import "contracts/resolvers/BaseResolver.sol";
import "test/mocks/MockBaseResolver.sol";
import "test/mocks/MockHandshakeNft.sol";

contract TestBaseResolver is Test {
    MockBaseResolver resolver;
    MockHandshakeNft tld;
    MockHandshakeNft sld;

    function setUp() public {
        tld = new MockHandshakeNft();
        sld = new MockHandshakeNft();

        resolver = new MockBaseResolver(tld, sld);
    }

    function testAuthorisedModifierFromTldOwner_success() public {
        address owner = address(0x1337);
        uint256 id = 420;

        tld.mint(owner, id);

        vm.prank(owner);
        resolver.incrementVersionPublicAuthorisedMethod(bytes32(id));
    }

    function testAuthorisedModiofierFromTldApprovedAddress_success() public {
        address owner = address(0x1337);
        address approved = address(0x69420);

        uint256 id = 420;

        tld.mint(owner, id);

        vm.prank(owner);
        tld.setApprovalForAll(approved, true);

        vm.prank(approved);
        resolver.incrementVersionPublicAuthorisedMethod(bytes32(id));
    }

    function testAuthorisedModifierFromSldOwner_success() public {
        address owner = address(0x1337);
        uint256 id = 420;

        sld.mint(owner, id);

        vm.prank(owner);
        resolver.incrementVersionPublicAuthorisedMethod(bytes32(id));
    }

    function testIncrementVersions_success(uint8 _iterations) public {
        address owner = address(0x1337);
        uint256 id = 420;
        uint256 id2 = 69;

        sld.mint(owner, id);
        sld.mint(owner, id2);

        vm.startPrank(owner);

        for (uint256 i; i < _iterations; i++) {
            resolver.incrementVersion(bytes32(id));
            resolver.incrementVersion(bytes32(id2));
        }

        assertEq(resolver.recordVersions(bytes32(id)), _iterations);
        assertEq(resolver.recordVersions(bytes32(id2)), _iterations);

        sld.transferFrom(owner, address(0x696969), id);

        vm.expectRevert("not authorised or owner");
        resolver.incrementVersion(bytes32(id));
    }

    function testAuthorisedModifierFromSldApprovedAddress_success() public {
        address owner = address(0x1337);
        address approved = address(0x69420);
        uint256 id = 420;

        sld.mint(owner, id);

        vm.prank(owner);
        sld.setApprovalForAll(approved, true);

        vm.prank(approved);
        resolver.incrementVersion(bytes32(id));
    }

    function testNotAuthorisedSldUser_fail() public {
        address owner = address(0x1337);
        address notApproved = address(0x69420);
        uint256 id = 420;

        sld.mint(owner, id);

        vm.prank(notApproved);
        vm.expectRevert("not authorised or owner");
        resolver.incrementVersion(bytes32(id));
    }

    function testNotAuthorisedTldUser_fail() public {
        address owner = address(0x1337);
        address notApproved = address(0x69420);
        uint256 id = 420;

        tld.mint(owner, id);

        vm.prank(notApproved);
        vm.expectRevert("not authorised or owner");
        resolver.incrementVersion(bytes32(id));
    }

    function testAddDelegateFromOwner() public {
        address owner = address(0x1337);
        address delegate = address(0x69420);
        uint256 id = 420;

        tld.mint(owner, id);

        vm.prank(owner);
        resolver.setDelegate(id, delegate);

        assertEq(resolver.delegates(owner, id), delegate);

        vm.prank(delegate);
        resolver.incrementVersion(bytes32(id));
    }

    function testAddDelegateFromNotOwner_fail() public {
        address owner = address(0x1337);
        address not_owner = address(0x696969);
        address delegate = address(0x69420);
        uint256 id = 420;

        tld.mint(owner, id);

        vm.prank(not_owner);
        vm.expectRevert("not authorised or owner");
        resolver.setDelegate(id, delegate);
    }

    function testRemoveDelegateFromOwner() public {
        address owner = address(0x1337);
        address delegate = address(0x69420);
        address new_delegate = address(0x696969);
        uint256 id = 420;

        tld.mint(owner, id);

        vm.prank(owner);
        resolver.setDelegate(id, delegate);

        assertEq(resolver.delegates(owner, id), delegate);

        vm.prank(owner);
        resolver.setDelegate(id, new_delegate);

        assertEq(resolver.delegates(owner, id), new_delegate);

        vm.prank(delegate);
        vm.expectRevert("not authorised or owner");
        resolver.incrementVersion(bytes32(id));
    }

    function testRemoveDelegateFromNotOwner_fail() public {
        address owner = address(0x1337);
        address not_owner = address(0x123456);
        address delegate = address(0x69420);
        address new_delegate = address(0x696969);
        uint256 id = 420;

        tld.mint(owner, id);

        vm.prank(owner);
        resolver.setDelegate(id, delegate);

        assertEq(resolver.delegates(owner, id), delegate);

        vm.prank(not_owner);
        vm.expectRevert("not authorised or owner");
        resolver.setDelegate(id, new_delegate);
    }

    function testTransferTokenDelegateReset() public {
        address owner = address(0x1337);
        address new_owner = address(0x696969);
        address delegate = address(0x69420);

        uint256 id = 420;

        tld.mint(owner, id);

        vm.prank(owner);
        resolver.setDelegate(id, delegate);

        assertEq(resolver.delegates(owner, id), delegate);

        vm.prank(owner);
        tld.safeTransferFrom(owner, new_owner, id);

        vm.prank(delegate);
        vm.expectRevert("not authorised or owner");
        resolver.incrementVersion(bytes32(id));
    }
}

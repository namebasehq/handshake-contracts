// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

import "test/mocks/TestResolvers.sol";
import "test/mocks/MockHandshakeNft.sol";

contract TestAddressResolver is Test {
    TestingAddressResolver resolver;
    MockHandshakeNft tld;
    MockHandshakeNft sld;

    function setUp() public {
        tld = new MockHandshakeNft();
        sld = new MockHandshakeNft();

        resolver = new TestingAddressResolver(tld, sld);
    }

    function testSetAddressFromOwner_success() public {
        address owner = address(0x99887766);
        uint256 id = 696969;
        vm.prank(owner);
        sld.mint(owner, id);

        address newAddress = address(0xbada55);

        //default should resolve to owner of the NFT
        assertEq(address(resolver.addr(bytes32(id))), owner, "address does not match");

        vm.prank(owner);
        resolver.setAddress(bytes32(id), newAddress);

        assertEq(address(resolver.addr(bytes32(id))), newAddress, "address does not match");
    }

    function testSetAddressFromApprovedAddress_success() public {
        address owner = address(0x99887766);
        address approved = address(0x123456);

        uint256 id = 696969;
        vm.prank(owner);
        sld.mint(owner, id);

        vm.prank(owner);
        sld.setApprovalForAll(approved, true);

        address newAddress = address(0xbada55);

        //default should resolve to owner of the NFT
        assertEq(resolver.addr(bytes32(id)), owner, "address does not match");

        vm.prank(approved);
        resolver.setAddress(bytes32(id), newAddress);

        assertEq(resolver.addr(bytes32(id)), newAddress, "address does not match");
    }

    function testSetAddressFromNotApprovedAddress_fail() public {
        address owner = address(0x99887766);
        address notApproved = address(0x123456);

        uint256 id = 696969;
        vm.prank(owner);
        sld.mint(owner, id);

        vm.expectRevert("not authorised or owner");
        vm.prank(notApproved);
        resolver.setAddress(bytes32(id), address(0x4));
    }

    function testSetAddressIncrementVersionsCheckAddressIsReset() public {
        address owner = address(0x99887766);
        uint256 id = 696969;
        vm.prank(owner);
        sld.mint(owner, id);

        address newAddress = address(0xbada55);

        //default should resolve to owner of the NFT
        assertEq(resolver.addr(bytes32(id)), owner, "address does not match");

        vm.prank(owner);
        resolver.setAddress(bytes32(id), newAddress);

        assertEq(resolver.addr(bytes32(id)), newAddress, "address does not match");

        vm.prank(owner);
        resolver.incrementVersion(bytes32(id));

        //default should resolve to owner of the NFT
        assertEq(resolver.addr(bytes32(id)), owner, "address does not match");
    }

    function testMintSldFromOwnerAndTransfer() public {
        address owner = address(0x99887766);
        address newOwner = address(0x55555555);
        uint256 id = 696969;
        vm.prank(owner);
        sld.mint(owner, id);

        //default should resolve to owner of the NFT
        assertEq(address(resolver.addr(bytes32(id))), owner, "address does not match");

        vm.prank(owner);
        sld.safeTransferFrom(owner, newOwner, id);

        assertEq(address(resolver.addr(bytes32(id))), newOwner, "address does not match");
    }

    function testMintTldFromOwnerAndTransfer() public {
        address owner = address(0x99887766);
        address newOwner = address(0x55555555);
        uint256 id = 696969;
        vm.prank(owner);
        tld.mint(owner, id);

        //default should resolve to owner of the NFT
        assertEq(address(resolver.addr(bytes32(id))), owner, "address does not match");

        vm.prank(owner);
        tld.safeTransferFrom(owner, newOwner, id);

        assertEq(address(resolver.addr(bytes32(id))), newOwner, "address does not match");
    }

    function testMintTldFromOwnerAndTransferCheckEthAddress() public {
        address owner = address(0x99887766);
        address newOwner = address(0x55555555);
        uint256 id = 696969;
        vm.prank(owner);
        tld.mint(owner, id);

        uint256 cointype = 60;

        //default should resolve to owner of the NFT
        assertEq(
            address(bytes20(resolver.addr(bytes32(id), cointype))),
            owner,
            "address does not match"
        );

        vm.prank(owner);
        tld.safeTransferFrom(owner, newOwner, id);

        assertEq(
            address(bytes20(resolver.addr(bytes32(id), cointype))),
            newOwner,
            "address does not match"
        );
    }

    function testMintTldFromOwnerAndTransferCheckOptimismAddress() public {
        address owner = address(0x99887766);
        address newOwner = address(0x55555555);
        uint256 id = 696969;
        vm.prank(owner);
        tld.mint(owner, id);

        uint256 cointype = 69;

        //default should resolve to owner of the NFT
        assertEq(
            address(bytes20(resolver.addr(bytes32(id), cointype))),
            owner,
            "address does not match"
        );

        vm.prank(owner);
        tld.safeTransferFrom(owner, newOwner, id);

        assertEq(
            address(bytes20(resolver.addr(bytes32(id), cointype))),
            newOwner,
            "address does not match"
        );
    }

    function testMintTldFromOwnerAndTransferCheckOtherChainsAddress(uint256 _cointype) public {
        address owner = address(0x99887766);
        address newOwner = address(0x55555555);
        address altWallet = address(0x12345678);
        uint256 id = 696969;
        vm.prank(owner);
        tld.mint(owner, id);

        bytes memory wallet = abi.encodePacked(altWallet);

        //default should resolve to owner of the NFT
        assertTrue(
            address(bytes20(resolver.addr(bytes32(id), _cointype))) == owner,
            "address does not match"
        );

        vm.startPrank(owner);
        resolver.setAddress(bytes32(id), wallet, _cointype);

        assertTrue(
            address(bytes20(resolver.addr(bytes32(id), _cointype))) == altWallet,
            "address does not match"
        );

        tld.safeTransferFrom(owner, newOwner, id);
        vm.stopPrank();
        assertTrue(
            address(bytes20(resolver.addr(bytes32(id), _cointype))) == newOwner,
            "address does not match"
        );

        vm.startPrank(newOwner);
        tld.safeTransferFrom(newOwner, owner, id);
        assertTrue(
            address(bytes20(resolver.addr(bytes32(id), _cointype))) == altWallet,
            "address does not match"
        );
    }
}

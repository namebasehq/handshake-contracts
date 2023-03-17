// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import "test/mocks/TestResolvers.sol";
import "test/mocks/MockHandshakeNft.sol";

//import "utils/NameEncoder.sol";
import {NameEncoder} from "@ensdomains/ens-contracts/contracts/utils/NameEncoder.sol";

contract TestDNSResolver is Test {
    using NameEncoder for string;
    TestingDNSResolver resolver;
    MockHandshakeNft tld;
    MockHandshakeNft sld;

    function setUp() public {
        tld = new MockHandshakeNft();
        sld = new MockHandshakeNft();

        resolver = new TestingDNSResolver(tld, sld);
    }

    function testSetBasicDNSRecords() public {
        address owner = address(0x99887766);
        uint256 id = 696969;
        sld.mint(owner, id);

        bytes32 node = bytes32(id);

        // a.eth. 3600 IN A 1.2.3.4
        bytes memory arec = hex"016103657468000001000100000e10000401020304";
        // b.eth. 3600 IN A 2.3.4.5
        bytes memory b1rec = hex"016203657468000001000100000e10000402030405";
        // b.eth. 3600 IN A 3.4.5.6
        bytes memory b2rec = hex"016203657468000001000100000e10000403040506";
        // eth. 86400 IN SOA ns1.ethdns.xyz. hostmaster.test.eth. 2018061501 15620 1800 1814400 14400
        bytes
            memory soarec = hex"03657468000006000100015180003a036e733106657468646e730378797a000a686f73746d6173746572057465737431036574680078492cbd00003d0400000708001baf8000003840";
        bytes memory rec = abi.encodePacked(arec, b1rec, b2rec, soarec);

        vm.prank(owner);
        resolver.setDNSRecords(node, rec);

        string memory aDotEth = "a.eth";
        string memory bDotEth = "b.eth";
        string memory ethDot = "eth";

        (bytes memory aName, ) = aDotEth.dnsEncodeName();
        (bytes memory bName, ) = bDotEth.dnsEncodeName();
        (bytes memory ethName, ) = ethDot.dnsEncodeName();

        assertEq(
            resolver.dnsRecord(node, keccak256(aName), 1),
            hex"016103657468000001000100000e10000401020304"
        );

        assertEq(
            resolver.dnsRecord(node, keccak256(bName), 1),
            hex"016203657468000001000100000e10000402030405016203657468000001000100000e10000403040506"
        );

        assertEq(
            resolver.dnsRecord(node, keccak256(ethName), 6),
            hex"03657468000006000100015180003a036e733106657468646e730378797a000a686f73746d6173746572057465737431036574680078492cbd00003d0400000708001baf8000003840"
        );
    }

    function testUpdateDnsRecordsFromOwner() public {
        address owner = address(0x99887766);
        uint256 id = 696969;
        sld.mint(owner, id);

        bytes32 node = bytes32(id);

        bytes memory firstARec = hex"016103657468000001000100000e10000401020306";

        // a.eth. 3600 IN A 1.2.3.4
        bytes memory arec = hex"016103657468000001000100000e10000401020304";

        // eth. 86400 IN SOA ns1.ethdns.xyz. hostmaster.test.eth. 2018061501 15620 1800 1814400 14400
        bytes
            memory soarec = hex"03657468000006000100015180003a036e733106657468646e730378797a000a686f73746d6173746572057465737431036574680078492cbd00003d0400000708001baf8000003840";

        vm.prank(owner);
        resolver.setDNSRecords(node, abi.encodePacked(firstARec, soarec));

        bytes memory rec = abi.encodePacked(arec, soarec);

        string memory aDotEth = "a.eth";
        string memory ethDot = "eth";

        (bytes memory aName, ) = aDotEth.dnsEncodeName();
        (bytes memory ethName, ) = ethDot.dnsEncodeName();

        //original value
        assertEq(
            resolver.dnsRecord(node, keccak256(aName), 1),
            hex"016103657468000001000100000e10000401020306"
        );

        vm.prank(owner);
        resolver.setDNSRecords(node, rec);

        assertEq(
            resolver.dnsRecord(node, keccak256(aName), 1),
            hex"016103657468000001000100000e10000401020304"
        );

        assertEq(
            resolver.dnsRecord(node, keccak256(ethName), 6),
            hex"03657468000006000100015180003a036e733106657468646e730378797a000a686f73746d6173746572057465737431036574680078492cbd00003d0400000708001baf8000003840"
        );
    }

    function testKeepTrackOfEntries() public {
        address owner = address(0x99887766);
        uint256 id = 696969;
        sld.mint(owner, id);

        bytes32 node = bytes32(id);

        string memory cDotEth = "c.eth";
        string memory dDotEth = "d.eth";

        (bytes memory cName, ) = cDotEth.dnsEncodeName();
        (bytes memory dName, ) = dDotEth.dnsEncodeName();

        // c.eth. 3600 IN A 1.2.3.4
        bytes memory crec = hex"016303657468000001000100000e10000401020304";

        vm.startPrank(owner);
        resolver.setDNSRecords(node, crec);

        assertTrue(resolver.hasDNSRecords(node, keccak256(cName)));
        assertFalse(resolver.hasDNSRecords(node, keccak256(dName)));

        resolver.setDNSRecords(node, crec);

        //updating makes no difference
        assertTrue(resolver.hasDNSRecords(node, keccak256(cName)));
        assertFalse(resolver.hasDNSRecords(node, keccak256(dName)));

        bytes memory crec2 = hex"016303657468000001000100000e100000";

        resolver.setDNSRecords(node, crec2);
        assertFalse(resolver.hasDNSRecords(node, keccak256(cName)));
    }

    function testSetSingleRecord() public {
        address owner = address(0x99887766);
        uint256 id = 696969;
        sld.mint(owner, id);

        bytes32 node = bytes32(id);

        string memory eDotEth = "e.eth";

        bytes memory erec = hex"016503657468000001000100000e10000401020304";

        (bytes memory eName, ) = eDotEth.dnsEncodeName();

        vm.startPrank(owner);
        resolver.setDNSRecords(node, erec);

        assertTrue(resolver.hasDNSRecords(node, keccak256(eName)));
        assertEq(
            resolver.dnsRecord(node, keccak256(eName), 1),
            hex"016503657468000001000100000e10000401020304"
        );
    }

    function testSetSingleRecordFromApprovedAddress() public {
        address owner = address(0x99887766);
        address approved = address(0x420420);
        uint256 id = 696969;
        sld.mint(owner, id);

        bytes32 node = bytes32(id);

        string memory eDotEth = "e.eth";

        bytes memory erec = hex"016503657468000001000100000e10000401020304";

        (bytes memory eName, ) = eDotEth.dnsEncodeName();

        vm.prank(owner);
        sld.setApprovalForAll(approved, true);

        vm.prank(approved);
        resolver.setDNSRecords(node, erec);

        assertTrue(resolver.hasDNSRecords(node, keccak256(eName)));
        assertEq(
            resolver.dnsRecord(node, keccak256(eName), 1),
            hex"016503657468000001000100000e10000401020304"
        );

        vm.prank(owner);
        sld.setApprovalForAll(approved, false);

        vm.expectRevert(BaseResolver.NotApprovedOrOwner.selector);
        vm.prank(approved);
        resolver.setDNSRecords(node, erec);
    }

    function testSetDnsFromNotApprovedAddress() public {
        address owner = address(0x99887766);
        uint256 id = 696969;
        sld.mint(owner, id);

        bytes32 node = bytes32(id);

        vm.expectRevert(BaseResolver.NotApprovedOrOwner.selector);
        resolver.setDNSRecords(node, bytes("irrelevant string"));
    }

    function testSetDnsZoneHashFromOwner() public {
        address owner = address(0x99887766);
        uint256 id = 696969;
        sld.mint(owner, id);

        bytes32 node = bytes32(id);
        bytes memory zonehash = hex"04";

        vm.prank(owner);
        resolver.setZonehash(node, zonehash);

        assertEq(resolver.zonehash(node), zonehash);
    }

    function testSetDnsZoneHashFromApprovedAddress() public {
        address owner = address(0x99887766);
        address approved = address(0x445566);
        uint256 id = 696969;
        sld.mint(owner, id);

        bytes32 node = bytes32(id);
        bytes memory zonehash = hex"ab";

        vm.prank(owner);
        sld.setApprovalForAll(approved, true);

        vm.prank(approved);
        resolver.setZonehash(node, zonehash);

        assertEq(resolver.zonehash(node), zonehash);
    }

    function testSetDnsZoneHashFromNotApprovedAddress_fail() public {
        address owner = address(0x99887766);
        address notApproved = address(0x445566);
        uint256 id = 696969;
        sld.mint(owner, id);

        bytes32 node = bytes32(id);
        bytes memory zonehash = hex"ab";

        vm.expectRevert(BaseResolver.NotApprovedOrOwner.selector);
        vm.prank(notApproved);
        resolver.setZonehash(node, zonehash);

        assertEq(resolver.zonehash(node), bytes(""));
    }

    function testSetDnsZoneHashAndOverwrite() public {
        address owner = address(0x99887766);
        uint256 id = 696969;
        sld.mint(owner, id);

        bytes32 node = bytes32(id);
        bytes memory zonehash = hex"04";
        bytes memory zonehash2 = hex"420690";

        vm.startPrank(owner);
        resolver.setZonehash(node, zonehash);

        assertEq(resolver.zonehash(node), zonehash);

        resolver.setZonehash(node, zonehash2);
        assertEq(resolver.zonehash(node), zonehash2);
    }

    function testReturnsEmptyBytesForNotExistingZonehash() public {
        assertEq(resolver.zonehash(bytes32(uint256(123456789))), hex"");
    }

    function testResetDnsOnVersionIncrement() public {
        address owner = address(0x99887766);
        uint256 id = 696969;
        sld.mint(owner, id);

        bytes32 node = bytes32(id);

        string memory eDotEth = "e.eth";

        bytes memory erec = hex"016503657468000001000100000e10000401020304";

        (bytes memory eName, ) = eDotEth.dnsEncodeName();

        vm.startPrank(owner);
        resolver.setDNSRecords(node, erec);

        assertTrue(resolver.hasDNSRecords(node, keccak256(eName)));
        assertEq(
            resolver.dnsRecord(node, keccak256(eName), 1),
            hex"016503657468000001000100000e10000401020304"
        );

        assertTrue(resolver.hasDNSRecords(node, keccak256(eName)));

        resolver.incrementVersion(node);

        assertFalse(resolver.hasDNSRecords(node, keccak256(eName)));

        assertEq(resolver.dnsRecord(node, keccak256(eName), 1), hex"");
    }

    function testResetDnsZoneOnVersionIncrement() public {
        address owner = address(0x99887766);
        uint256 id = 696969;
        sld.mint(owner, id);

        bytes32 node = bytes32(id);
        bytes memory zonehash = hex"04";

        vm.startPrank(owner);
        resolver.setZonehash(node, zonehash);

        assertEq(resolver.zonehash(node), zonehash);

        resolver.incrementVersion(node);

        assertEq(resolver.zonehash(node), hex"");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import {Namehash} from "utils/Namehash.sol";
import "interfaces/ILabelValidator.sol";
import "contracts/SldRegistrationManager.sol";
import "mocks/MockGlobalRegistrationStrategy.sol";
import "mocks/MockLabelValidator.sol";
import "mocks/MockHandshakeTld.sol";
import "mocks/MockHandshakeSld.sol";
import "mocks/MockCommitIntent.sol";
import "mocks/MockRegistrationStrategy.sol";
import "mocks/MockGasGriefingRegistrationStrategy.sol";
import "src/utils/Namehash.sol";
import "structs/SldRegistrationDetail.sol";
import "mocks/MockUsdOracle.sol";
import "./SldRegistrationManagerBase.t.sol";

contract TestSldRegistrationManagerRegisterSldTests is TestSldRegistrationManagerBase {
    uint256 internal privateKey = 0xb0b;

    function setUp() public override {
        vm.warp(365 days);
        super.setUp();
    }

    function testRegisterSldWithValidSignature() public {
        address sendingAddress = address(0x420);
        bytes32 parentNamehash = bytes32(uint256(0x55446677));

        bytes32 digest = manager.getRegistrationHash(sendingAddress, Namehash.getNamehash(parentNamehash, "labellabel"));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        address signingAddress = vm.addr(privateKey);

        manager.updateSigner(signingAddress, true);

        bytes memory signature = abi.encodePacked(v, r, s);

        setUpLabelValidator();
        setUpGlobalStrategy(true, true, 1 ether);

        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);

        bytes32 secret = 0x0;
        uint80 registrationLength = 500;

        address recipient = address(0xbadbad);

        hoax(sendingAddress, 2 ether);
        vm.expectCall(
            address(manager.sld()), abi.encodeCall(manager.sld().registerSld, (recipient, parentNamehash, "labellabel"))
        );
        vm.prank(sendingAddress);
        manager.registerWithSignature{value: 2 ether}(
            "labellabel", registrationLength, parentNamehash, recipient, v, r, s
        );
    }

    function testRegisterSldWithInvalidSignature() public {
        address sendingAddress = address(0x420);
        bytes32 parentNamehash = bytes32(uint256(0x55446677));

        bytes32 sldNamehash = Namehash.getNamehash(parentNamehash, "foobar");

        bytes32 digest = keccak256(abi.encodePacked(sendingAddress, sldNamehash, uint256(0)));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        setUpLabelValidator();
        setUpGlobalStrategy(true, true, 1 ether);

        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);

        bytes32 secret = 0x0;
        uint80 registrationLength = 500;
        address recipient = address(0xbadbad);

        hoax(sendingAddress, 2 ether);
        vm.expectRevert("invalid signature");
        manager.registerWithSignature{value: 2 ether}("foobar", registrationLength, parentNamehash, recipient, v, r, s);
    }

    function testRegisterAfterExpiry() public {
        address initialSendingAddress = address(0x420);
        bytes32 parentNamehash = bytes32(uint256(0x55446677));

        // Initial registration digest
        bytes32 digest =
            manager.getRegistrationHash(initialSendingAddress, Namehash.getNamehash(parentNamehash, "labellabel"));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        address signingAddress = vm.addr(privateKey);

        manager.updateSigner(signingAddress, true);

        bytes memory signature = abi.encodePacked(v, r, s);

        setUpLabelValidator();
        setUpGlobalStrategy(true, true, 1 ether);

        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);

        bytes32 secret = bytes32(uint256(0x1337));
        uint80 registrationLength = 500;
        address recipient = address(0xbadbad);

        // Initial registration
        startHoax(initialSendingAddress, 2 ether);
        vm.expectCall(
            address(manager.sld()), abi.encodeCall(manager.sld().registerSld, (recipient, parentNamehash, "labellabel"))
        );

        manager.registerWithSignature{value: 2 ether}(
            "labellabel", registrationLength, parentNamehash, recipient, v, r, s
        );

        // Warp 500 days + 30 day grace period
        vm.warp(block.timestamp + (500 days) + (30 days) + 1);

        // Register again from a different wallet after expiry
        address newSendingAddress = address(0x123);

        // Generate new digest for the new wallet after expiry
        bytes32 newDigest =
            manager.getRegistrationHash(newSendingAddress, Namehash.getNamehash(parentNamehash, "labellabel"));
        (uint8 newV, bytes32 newR, bytes32 newS) = vm.sign(privateKey, newDigest);

        startHoax(newSendingAddress, 2 ether);

        manager.registerWithSignature{value: 2 ether}(
            "labellabel", registrationLength, parentNamehash, newSendingAddress, newV, newR, newS
        );
    }
}

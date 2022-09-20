// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

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
import "src/utils/Namehash.sol";
import "structs/SubdomainRegistrationDetail.sol";

contract TestSldRegistrationManager is Test {
    SldRegistrationManager manager;

    MockHandshakeSld sld;
    MockHandshakeTld tld;
    MockCommitIntent commitIntent;

    function setUp() public {
        sld = new MockHandshakeSld();
        tld = new MockHandshakeTld();
        commitIntent = new MockCommitIntent(true);
        manager = new SldRegistrationManager(tld, sld, commitIntent);
    }

    function setUpLabelValidator() public {
        ILabelValidator validator = new MockLabelValidator(true);
        manager.updateLabelValidator(validator);
    }

    function setUpGlobalRules(bool _result) public {
        IGlobalRegistrationRules globalRules = new MockGlobalRegistrationStrategy(_result);
        manager.updateGlobalRegistrationStrategy(globalRules);
    }

    function setUpRegistrationStrategy(bytes32 _parentNamehash) public {
        ISldRegistrationStrategy strategy = new MockRegistrationStrategy(1 ether); // $1 per year
        sld.setMockRegistrationStrategy(_parentNamehash, strategy);
    }

    function testUpdateLabelValidatorFromOwner_success() public {
        ILabelValidator validator = new MockLabelValidator(true);
        manager.updateLabelValidator(validator);

        assertEq(
            address(manager.labelValidator()),
            address(validator),
            "label validator not set correctly"
        );
    }

    function testUpdateLabelValidatorFromNotOwner_fail() public {
        ILabelValidator validator = new MockLabelValidator(true);
        vm.prank(address(0x420));
        vm.expectRevert("Ownable: caller is not the owner");
        manager.updateLabelValidator(validator);
    }

    function testPurchaseSldLabelValidatorReturnFalse_fail() public {
        ILabelValidator validator = new MockLabelValidator(false);
        manager.updateLabelValidator(validator);

        bytes32 parentNamehash = bytes32(uint256(0x4));

        setUpRegistrationStrategy(parentNamehash);
        setUpGlobalRules(true);

        string memory label = "yo";
        bytes32 secret = 0x0;
        uint256 registrationLength = 500;

        bytes32[] memory proofs = new bytes32[](0);

        address recipient = address(0x5555);

        vm.prank(address(0x420));
        vm.expectRevert("invalid label");
        manager.registerSld(label, secret, registrationLength, parentNamehash, recipient);
    }

    function testPurchaseSldGlobalRegistrationRulesReturnFalse_fail() public {
        setUpLabelValidator();
        bytes32 parentNamehash = bytes32(uint256(0x4));
        setUpRegistrationStrategy(parentNamehash);

        IGlobalRegistrationRules rules = new MockGlobalRegistrationStrategy(false);
        manager.updateGlobalRegistrationStrategy(rules);

        string memory label = "yo";
        bytes32 secret = 0x0;
        uint256 registrationLength = 500;

        bytes32[] memory proofs = new bytes32[](0);

        address recipient = address(0x5555);

        vm.prank(address(0x420));
        vm.expectRevert("failed global strategy");
        manager.registerSld(label, secret, registrationLength, parentNamehash, recipient);
    }

    function testMintSldFromAuthorisedWalletRepurchaseWhenExpired_success() public {
        ILabelValidator validator = new MockLabelValidator(true);
        manager.updateLabelValidator(validator);
        setUpGlobalRules(true);

        bytes32 parentNamehash = bytes32(uint256(0x4));
        setUpRegistrationStrategy(parentNamehash);

        string memory label = "yo";
        bytes32 secret = 0x0;
        uint256 registrationLength = 500;
        bytes32[] memory proofs = new bytes32[](0);

        address recipient = address(0x5555);

        vm.prank(address(0x420));

        manager.registerSld(label, secret, registrationLength, parentNamehash, recipient);

        vm.warp(block.timestamp + (registrationLength * 86400) + 1);

        manager.registerSld(label, secret, registrationLength, parentNamehash, recipient);
    }

    function testMintSldFromAuthorisedWalletRepurchaseWhenStillActive_fail() public {
        ILabelValidator validator = new MockLabelValidator(true);
        manager.updateLabelValidator(validator);

        bytes32 parentNamehash = bytes32(uint256(0x4));
        setUpRegistrationStrategy(parentNamehash);
        setUpGlobalRules(true);

        string memory label = "yo";
        bytes32 secret = 0x0;
        uint256 registrationLength = 500;

        bytes32[] memory proofs = new bytes32[](0);

        address recipient = address(0x5555);

        vm.prank(address(0x420));

        manager.registerSld(label, secret, registrationLength, parentNamehash, recipient);

        vm.warp(block.timestamp + (registrationLength * 86400) - 10);

        vm.expectRevert("domain already registered");
        manager.registerSld(label, secret, registrationLength, parentNamehash, recipient);
    }

    function testSetGlobalRegistrationStrategyFromContractOwner_pass() public {
        IGlobalRegistrationRules globalRules = new MockGlobalRegistrationStrategy(false);
        manager.updateGlobalRegistrationStrategy(globalRules);

        assertEq(
            address(manager.globalStrategy()),
            address(globalRules),
            "global registration rules not set correctly"
        );
    }

    function testSetGlobalRegistrationStrategyFromNotContractOwner_fail() public {
        IGlobalRegistrationRules globalRules = new MockGlobalRegistrationStrategy(false);

        vm.startPrank(address(0x1234));
        vm.expectRevert("Ownable: caller is not the owner");
        manager.updateGlobalRegistrationStrategy(globalRules);
    }

    function testMultiPurchasesldWithIncorrectArrayLengths_expectFail() public {}

    function testMultiPurchasesldWithIncorrectArrayLengths_expectFail_2() public {}

    function testMultiPurchasesld() public {}

    function testMultiPurchasesldWithZeroAddressInReceiver() public {}

    function testPurchaseSldToZeroAddress_expectSendToMsgSender() public {
        setUpLabelValidator();
        setUpGlobalRules(true);
        bytes32 parentNamehash = bytes32(uint256(0x226677));
        setUpRegistrationStrategy(parentNamehash);

        string memory label = "yo";
        bytes32 secret = 0x0;
        uint256 registrationLength = 500;

        bytes32[] memory proofs = new bytes32[](0);

        address recipient = address(0);

        address sendingAddress = address(0x420);
        vm.startPrank(sendingAddress);
        vm.expectCall(
            address(manager.sld()),
            abi.encodeCall(
                manager.sld().registerSld,
                (
                    sendingAddress,
                    parentNamehash,
                    0xed072e419684a4889ae9f5a41b9caaf11717570d6bb2af070217e1aec0d61f23
                )
            )
        );
        manager.registerSld(label, secret, registrationLength, parentNamehash, recipient);
    }

    function testPurchaseSldToOtherAddress() public {
        setUpLabelValidator();
        setUpGlobalRules(true);
        bytes32 parentNamehash = bytes32(uint256(0x55446677));
        setUpRegistrationStrategy(parentNamehash);
        string memory label = "yo";
        bytes32 secret = 0x0;
        uint256 registrationLength = 500;

        bytes32[] memory proofs = new bytes32[](0);

        address recipient = address(0xbadbad);

        address sendingAddress = address(0x420);
        vm.startPrank(sendingAddress);
        vm.expectCall(
            address(manager.sld()),
            abi.encodeCall(
                manager.sld().registerSld,
                (recipient, parentNamehash, Namehash.getNamehash(parentNamehash, label))
            )
        );
        manager.registerSld(label, secret, registrationLength, parentNamehash, recipient);
    }

    function testMintSingleDomainWithNoPriceStrategy_fail() public {
        setUpLabelValidator();
        setUpGlobalRules(true);

        string memory label = "yo";
        bytes32 secret = 0x0;
        uint256 registrationLength = 500;
        bytes32 parentNamehash = bytes32(uint256(0x55446677));

        bytes32[] memory proofs = new bytes32[](0);

        address recipient = address(0xbadbad);

        address sendingAddress = address(0x420);

        vm.prank(sendingAddress);
        vm.expectRevert("no registration strategy");
        manager.registerSld(label, secret, registrationLength, parentNamehash, recipient);
    }

    function testMintSingleDomainCheckHistory() public {
        setUpLabelValidator();
        setUpGlobalRules(true);

        string memory label = "yo";
        bytes32 secret = 0x0;
        uint256 registrationLength = 365;
        bytes32 parentNamehash = bytes32(uint256(0x55446677));
        setUpRegistrationStrategy(parentNamehash);
        bytes32[] memory proofs = new bytes32[](0);

        address recipient = address(0xbadbad);

        address sendingAddress = address(0x420);
        vm.startPrank(sendingAddress);
        vm.expectCall(
            address(manager.sld()),
            abi.encodeCall(
                manager.sld().registerSld,
                (
                    recipient,
                    parentNamehash,
                    0xc9deaae6135f5bffc91df7e1f3e69359942c17c296519680019a467d0e78ddc5
                )
            )
        );

        manager.registerSld(label, secret, registrationLength, parentNamehash, recipient);

        bytes32 subdomainNamehash = Namehash.getNamehash(parentNamehash, label);

        (
            uint80 actualRegistrationTime,
            uint80 actualRegistrationLength,
            uint96 actualRegistrationPrice
        ) = manager.subdomainRegistrationHistory(subdomainNamehash);

        assertEq(actualRegistrationTime, block.timestamp, "registration time incorrect");
        assertEq(actualRegistrationLength, registrationLength, "registration length incorrect");
        assertEq(actualRegistrationPrice, 1 ether, "registration price incorrect");

        uint128[10] memory pricing = manager.getTenYearGuarenteedPricing(subdomainNamehash);

        for (uint256 i; i < 10; i++) {
            assertEq(pricing[i], (i + 1) * 1 ether, "issue with historic pricing");
        }
    }

    function testRenewSubdomainFromSldOwner_pass() public {}

    //TODO: what's the expected behaviour (pass i think)
    function testRenewSubdomainFromNotSldOwner_whatDoWeWantToDo() public {}

    function testRenewNoneExistingToken_fail() public {}

    function testRenewExpiredSld_fail() public {}
}

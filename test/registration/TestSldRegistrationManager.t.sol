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

contract TestSldRegistrationManager is Test {
    SldRegistrationManager manager;

    function setUp() public {
        MockHandshakeSld sld = new MockHandshakeSld();
        MockHandshakeTld tld = new MockHandshakeTld();
        manager = new SldRegistrationManager(tld, sld);
    }

    function setUpLabelValidator() public {
        ILabelValidator validator = new MockLabelValidator(true);
        manager.updateLabelValidator(validator);
    }

    function setUpGlobalRules() public {
        IGlobalRegistrationRules globalRules = new MockGlobalRegistrationStrategy(false);
        manager.updateGlobalRegistrationStrategy(globalRules);
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

        string memory label = "yo";
        bytes32 secret = 0x0;
        uint256 registrationLength = 500;
        bytes32 parentNamehash = 0x0;
        bytes32[] memory proofs = new bytes32[](0);

        address recipient = address(0x5555);

        vm.prank(address(0x420));
        vm.expectRevert("invalid label");
        manager.registerSld(label, secret, registrationLength, parentNamehash, proofs, recipient);
    }

    function testMintSldFromAuthorisedWalletRepurchaseWhenExpired_success() public {
        ILabelValidator validator = new MockLabelValidator(true);
        manager.updateLabelValidator(validator);

        string memory label = "yo";
        bytes32 secret = 0x0;
        uint256 registrationLength = 500;
        bytes32 parentNamehash = 0x0;
        bytes32[] memory proofs = new bytes32[](0);

        address recipient = address(0x5555);

        vm.prank(address(0x420));

        manager.registerSld(label, secret, registrationLength, parentNamehash, proofs, recipient);

        vm.warp(block.timestamp + (registrationLength * 86400));

        manager.registerSld(label, secret, registrationLength, parentNamehash, proofs, recipient);
    }

    function testMintSldFromAuthorisedWalletRepurchaseWhenStilActive_fail() public {
        ILabelValidator validator = new MockLabelValidator(true);
        manager.updateLabelValidator(validator);

        string memory label = "yo";
        bytes32 secret = 0x0;
        uint256 registrationLength = 500;
        bytes32 parentNamehash = 0x0;
        bytes32[] memory proofs = new bytes32[](0);

        address recipient = address(0x5555);

        vm.prank(address(0x420));

        manager.registerSld(label, secret, registrationLength, parentNamehash, proofs, recipient);

        vm.warp(block.timestamp + (registrationLength * 86400) - 10);

        vm.expectRevert("domain already registered");
        manager.registerSld(label, secret, registrationLength, parentNamehash, proofs, recipient);
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
        setUpGlobalRules();

        string memory label = "yo";
        bytes32 secret = 0x0;
        uint256 registrationLength = 500;
        bytes32 parentNamehash = 0x0;
        bytes32[] memory proofs = new bytes32[](0);

        address recipient = address(0);

        vm.prank(address(0x420));
        vm.expectCall(
            address(manager.sld()),
            abi.encodeCall(
                manager.sld().registerSld,
                (
                    recipient,
                    parentNamehash,
                    0xab5dd1bdf3bb990efe3a65bbfd47346dbf0974daf9c37506381381bb28f98651
                )
            )
        );
        manager.registerSld(label, secret, registrationLength, parentNamehash, proofs, recipient);
    }

    function testPurchaseSldToOtherAddress() public {}

    function testMintSingleDomainCheckHistory() public {}

    function testRegisterSubdomainForOneDollarLowestPrice_pass() public {}

    function testRenewSubdomainFromSldOwner_pass() public {}

    //TODO: what's the expected behaviour (pass i think)
    function testRenewSubdomainFromNotSldOwner_whatDoWeWantToDo() public {}

    function testRenewNoneExistingToken_fail() public {}

    function testRenewExpiredSld_fail() public { }
}

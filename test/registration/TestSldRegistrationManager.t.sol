// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import {Namehash} from "utils/Namehash.sol";
import "interfaces/ILabelValidator.sol";
import "contracts/SldRegistrationManager.sol";
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


    function testUpdateLabelValidatorFromOwner_success() public {

        ILabelValidator validator = new MockLabelValidator(true);
        manager.updateLabelValidator(validator);

        assertEq(address(manager.labelValidator()), address(validator), "label validator not set correctly");

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

    }

    function testSetGlobalRegistrationStrategyFromContractOwner_pass() public {

    }

    function testSetGlobalRegistrationStrategyFromNotContractOwner_fail() public {
        
    }

    function testSetGlobalRegistrationStrategyIncorrectInterfaceFromContractOwner_fail() public {

    }

    function testMintSldFromAuthorisedWalletWithMissingRegistrationStrategy() public {

    }

    function testMultiPurchasesldWithIncorrectArrayLengths_expectFail() public {

    }

    function testMultiPurchasesldWithIncorrectArrayLengths_expectFail_2() public {

    }

    function testMultiPurchasesld() public {

    }

    function testMultiPurchasesldWithZeroAddressInReceiver() public {

    }

    function testPurchaseSldToZeroAddress_expectSendToMsgSender() public {

    }

    function testPurchaseSldToOtherAddress() public {

    }

    function testMintSingleDomainCheckHistory() public {

    }

    function testRegisterSubdomainForOneDollarLowestPrice_pass() public {

    }

    function testRenewSubdomainFromSldOwner_pass() public {

    }

    //TODO: what's the expected behaviour (pass i think)
    function testRenewSubdomainFromNotSldOwner_whatDoWeWantToDo() public {

    }

    function testRenewNoneExistingToken_fail() public {}

    function testRenewExpiredSld_fail() public {
    
    }



}
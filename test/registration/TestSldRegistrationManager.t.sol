// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import {Namehash} from "utils/Namehash.sol";
import "contracts/SldRegistrationManager.sol";
import "mocks/MockLabelValidator.sol";


contract TestSldRegistrationManager is Test {

    function testUpdateLabelValidatorFromOwner_success() public {

    }

    function testUpdateLabelValidatorFromNotOwner_fail() public {

    }

    function testMintSldFromAuthorisedWallet() public {

    }

    function testMintSldFromAuthorisedWalletRepurchaseWhenExpired() public {

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
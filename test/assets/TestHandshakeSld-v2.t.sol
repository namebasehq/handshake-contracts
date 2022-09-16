// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import {Namehash} from "utils/Namehash.sol";
import "contracts/HandshakeSld-v2.sol";
import "utils/Namehash.sol";
import "interfaces/ITldClaimManager.sol";
import "interfaces/ISldRegistrationManager.sol";
import "test/mocks/MockClaimManager.sol";
import "test/mocks/MockCommitIntent.sol";
import "test/mocks/MockLabelValidator.sol";
import "test/mocks/MockHandshakeTld.sol";
import "test/mocks/MockRegistrationStrategy.sol";
import "test/mocks/MockUsdOracle.sol";
import "test/mocks/MockGlobalRegistrationStrategy.sol";
import "test/mocks/MockCommitIntent.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "interfaces/ICommitIntent.sol";

contract TestHandshakeSld_v2 is Test {
    error MissingRegistrationStrategy();

    using stdStorage for StdStorage;

    HandshakeSld_v2 sld;
    IHandshakeTld tld;

    function setUp() public {
        tld = new MockHandshakeTld();
        sld = new HandshakeSld_v2(tld);
    }

    function testMintSldFromRegistryAddress_success() public {}

    function testMintSldFromNotRegistryAddress_fail() public {}

    function testMintDuplicateSld_fail() public {}

    function testCheckParentNamehashIsCorrectAfterMint() public {}

    function testCheckLabelToNamehashIsCorrectAfterMint() public {}

    function testSetRoyaltyPaymentAddressForTldFromTldOwnerAddress() public {}

    function testSetRoyaltyPaymentAddressForTldNotSet_ShouldReturnTldOwner() public {}

    function testSetRoyaltyPaymentAddressThenTransferTld_AddressShouldResetToNewOwner() public {}

    function testSetRoyaltyPaymentAddressForTldFromTldOwnerApprovedAddress() public {}

    function testSetRoyaltyPaymentAddressForTldFromNotTldOwnerAddress_ExpectFail() public {}

    function testSetRoyaltyPaymentAmountForTldFromTldOwnerAddress() public {}

    function testSetRoyaltyPaymentAmountForTldNotSet_ShouldReturnZero() public {}

    function testSetRoyaltyPaymentAmountForTldFromTldOwnerApprovedAddress() public {}

    function testSetRoyaltyPaymentAmountForTldFromNotTldOwnerAddress_ExpectFail() public {}

    function testSetRoyaltyPaymentAmountForTldFromTldOwnerAddressOver10Percent_expectFail()
        public
    {}

    function testAddRegistrationStrategyToTldDomain_pass() public {}

    function testAddRegistrationStrategyToTldNotOwner_fail() public {}

    function testGetSubdomainDetailsValidationCheckShouldPassIfArrayLengthsAllTheSame() public {}

    function testGetSubdomainDetailsValidationCheckShouldFailIfArrayLengthsParentIdsDifferent()
        public
    {}

    function testGetSubdomainDetailsValidationCheckShouldFailIfArrayLengthsLabelsDifferent()
        public
    {}

    function testGetSubdomainDetailsValidationCheckShouldFailIfArrayLengthsRegistrationLengthsDifferent()
        public
    {}

    function testGetSubdomainDetailsValidationCheckShouldFailIfArrayLengthsProofsDifferent()
        public
    {}

    function testGetSubdomainDetailsValidationCheckShouldFailIfArrayLengthsRecipientsDifferent()
        public
    {}

    function testGetSubdomainDetails_single() public {}

    function testGetSubdomainDetails_multiple() public {}

    function testPurchaseSingleDomainGetRefundForExcess() public {}

    function testPurchaseTwoDomainGetRefundForExcess() public {}

    function testPurchaseSingleDomainFundsGetSentToOwnerAndHandshakeWallet() public {}

    function testSetHandshakeWalletAddressFromContractOwner_pass() public {}

    function testSetHandshakeWalletAddressToZeroAddressFromContractOwner_fail() public {}

    function testSetHandshakeWalletAddressFromNotContractOwner_fail() public {}
}

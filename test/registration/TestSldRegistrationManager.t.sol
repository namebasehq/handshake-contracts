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
import "mocks/MockUsdOracle.sol";

contract TestSldRegistrationManager is Test {
    SldRegistrationManager manager;
    using stdStorage for StdStorage;

    MockHandshakeSld sld;
    MockHandshakeTld tld;
    MockCommitIntent commitIntent;

    fallback() external payable {}

    receive() external payable {}

    function setUp() public {
        sld = new MockHandshakeSld();
        tld = new MockHandshakeTld();
        commitIntent = new MockCommitIntent(true);
        MockUsdOracle oracle = new MockUsdOracle(100000000); //$1
        manager = new SldRegistrationManager(tld, sld, commitIntent, oracle, address(this));
    }

    function addMockOracle() private {
        MockUsdOracle oracle = new MockUsdOracle(200000000000);
        stdstore.target(address(manager)).sig("usdOracle()").checked_write(address(oracle));
    }

    function setUpLabelValidator() public {
        ILabelValidator validator = new MockLabelValidator(true);
        manager.updateLabelValidator(validator);
    }

    function setUpGlobalStrategy(bool _result) public {
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

    function testUpdateUsdOracleFromOwner_pass() public {
        MockUsdOracle oracle = new MockUsdOracle(1);
        manager.updatePriceOracle(oracle);

        assertEq(address(manager.usdOracle()), address(oracle));
    }

    function testUpdateUsdOracleFromNotOwner_fail() public {
        MockUsdOracle oracle = new MockUsdOracle(1);
        vm.startPrank(address(0x112233));
        vm.expectRevert("Ownable: caller is not the owner");
        manager.updatePriceOracle(oracle);
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
        setUpGlobalStrategy(true);

        string memory label = "yo";
        bytes32 secret = 0x0;
        uint80 registrationLength = 500;

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
        uint80 registrationLength = 500;

        address recipient = address(0x5555);

        vm.prank(address(0x420));
        vm.expectRevert("failed global strategy");
        manager.registerSld(label, secret, registrationLength, parentNamehash, recipient);
    }

    function testMintSldFromAuthorisedWalletRepurchaseWhenExpired_success() public {
        ILabelValidator validator = new MockLabelValidator(true);
        manager.updateLabelValidator(validator);
        setUpGlobalStrategy(true);

        bytes32 parentNamehash = bytes32(uint256(0x4));
        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);

        string memory label = "yo";
        bytes32 secret = 0x0;
        uint80 registrationLength = 500;

        address recipient = address(0x5555);

        hoax(address(0x420), 4 ether);
        manager.registerSld{value: 2 ether}(
            label,
            secret,
            registrationLength,
            parentNamehash,
            recipient
        );

        vm.warp(block.timestamp + (registrationLength * 86400) + 1);

        vm.prank(address(0x420));
        manager.registerSld{value: 2 ether}(
            label,
            secret,
            registrationLength,
            parentNamehash,
            recipient
        );
    }

    function testMintSldFromAuthorisedWalletRepurchaseWhenStillActive_fail() public {
        ILabelValidator validator = new MockLabelValidator(true);
        manager.updateLabelValidator(validator);

        bytes32 parentNamehash = bytes32(uint256(0x4));
        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);
        setUpGlobalStrategy(true);

        string memory label = "yo";
        bytes32 secret = 0x0;
        uint80 registrationLength = 500;

        address recipient = address(0x5555);

        hoax(address(0x420), 4 ether);
        manager.registerSld{value: 2 ether}(
            label,
            secret,
            registrationLength,
            parentNamehash,
            recipient
        );

        vm.warp(block.timestamp + (registrationLength * 86400) - 10);

        vm.prank(address(0x420));
        vm.expectRevert("domain already registered");
        manager.registerSld{value: 2 ether}(
            label,
            secret,
            registrationLength,
            parentNamehash,
            recipient
        );
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

    function testPurchaseSldToZeroAddress_expectSendToMsgSender() public {
        setUpLabelValidator();
        setUpGlobalStrategy(true);
        bytes32 parentNamehash = bytes32(uint256(0x226677));
        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);

        string memory label = "yo";
        bytes32 secret = 0x0;
        uint80 registrationLength = 500;

        address recipient = address(0);

        address sendingAddress = address(0x420);
        hoax(sendingAddress, 20 ether);
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
        vm.startPrank(sendingAddress);
        manager.registerSld{value: (uint256(1 ether) / uint256(365)) * registrationLength + 137}(
            label,
            secret,
            registrationLength,
            parentNamehash,
            recipient
        );
    }

    function testPurchaseSldToOtherAddress() public {
        setUpLabelValidator();
        setUpGlobalStrategy(true);
        bytes32 parentNamehash = bytes32(uint256(0x55446677));
        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);
        string memory label = "yo";
        bytes32 secret = 0x0;
        uint80 registrationLength = 500;

        address recipient = address(0xbadbad);

        address sendingAddress = address(0x420);
        hoax(sendingAddress, 2 ether);
        vm.expectCall(
            address(manager.sld()),
            abi.encodeCall(
                manager.sld().registerSld,
                (recipient, parentNamehash, Namehash.getNamehash(parentNamehash, label))
            )
        );
        vm.prank(sendingAddress);
        manager.registerSld{value: 2 ether}(
            label,
            secret,
            registrationLength,
            parentNamehash,
            recipient
        );
    }

    function testMintSingleDomainWithNoPriceStrategy_fail() public {
        setUpLabelValidator();
        setUpGlobalStrategy(true);

        string memory label = "yo";
        bytes32 secret = 0x0;
        uint80 registrationLength = 500;
        bytes32 parentNamehash = bytes32(uint256(0x55446677));

        address recipient = address(0xbadbad);

        address sendingAddress = address(0x420);

        vm.prank(sendingAddress);
        vm.expectRevert("no registration strategy");
        manager.registerSld(label, secret, registrationLength, parentNamehash, recipient);
    }

    function testMintSingleDomainCheckHistory() public {
        setUpLabelValidator();
        setUpGlobalStrategy(true);

        string memory label = "yo";
        bytes32 secret = 0x0;
        uint80 registrationLength = 365;
        bytes32 parentNamehash = bytes32(uint256(0x55446677));
        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);

        address recipient = address(0xbadbad);

        address sendingAddress = address(0x420);
        hoax(sendingAddress, 20 ether);

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

        vm.startPrank(sendingAddress);
        manager.registerSld{value: 1 ether}(
            label,
            secret,
            registrationLength,
            parentNamehash,
            recipient
        );

        bytes32 subdomainNamehash = Namehash.getNamehash(parentNamehash, label);

        (
            uint80 actualRegistrationTime,
            uint80 actualRegistrationLength,
            uint96 actualRegistrationPrice
        ) = manager.subdomainRegistrationHistory(subdomainNamehash);

        assertEq(actualRegistrationTime, block.timestamp, "registration time incorrect");
        assertEq(
            actualRegistrationLength,
            registrationLength * 1 days,
            "registration length incorrect"
        );
        assertEq(actualRegistrationPrice, 1 ether, "registration price incorrect");

        uint128[10] memory pricing = manager.getTenYearGuarenteedPricing(subdomainNamehash);

        for (uint256 i; i < 10; i++) {
            //pricing should return back flat rate of 1 dollar per year regardless of length
            assertEq(pricing[i], 1 ether, "issue with historic pricing");
        }
    }

    function testRenewSubdomainFromSldOwner_pass() public {
        ILabelValidator validator = new MockLabelValidator(true);
        manager.updateLabelValidator(validator);
        setUpGlobalStrategy(true);

        bytes32 parentNamehash = bytes32(uint256(0x4));
        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);

        string memory label = "yo";
        bytes32 secret = 0x0;
        uint80 registrationLength = 500;
        uint80 renewalLength = 1200;

        address recipient = address(0x5555);

        startHoax(address(0x420), 50 ether);

        manager.registerSld{value: 2 ether}(
            label,
            secret,
            registrationLength,
            parentNamehash,
            recipient
        );

        manager.renewSubdomain{value: 5 ether}(label, parentNamehash, renewalLength);

        (
            uint80 actualRegistrationTime,
            uint80 actualRegistrationLength, // uint96 actualRegistrationPrice

        ) = manager.subdomainRegistrationHistory(Namehash.getNamehash(parentNamehash, label));

        uint256 expectedValue = actualRegistrationTime + actualRegistrationLength;
        uint256 actualValue = block.timestamp + ((registrationLength + renewalLength) * 1 days);

        //check that the registration details have been updated.
        assertEq(actualValue, expectedValue, "invalid registration details");
    }

    //TODO: what's the expected behaviour (pass i think)
    function testRenewSubdomainFromNotSldOwner_pass() public {
        ILabelValidator validator = new MockLabelValidator(true);
        manager.updateLabelValidator(validator);
        setUpGlobalStrategy(true);

        bytes32 parentNamehash = bytes32(uint256(0x4));
        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);

        string memory label = "yo";
        bytes32 secret = 0x0;
        uint80 registrationLength = 500;
        uint80 renewalLength = 1200;

        address recipient = address(0x5555);

        startHoax(address(0x420), 30 ether);

        manager.registerSld{value: 2 ether}(
            label,
            secret,
            registrationLength,
            parentNamehash,
            recipient
        );
        vm.stopPrank();

        uint256 registrationTimestamp = block.timestamp;
        vm.warp(block.timestamp + (registrationLength * 86400));

        //different wallet, can renew domain.
        startHoax(address(0x99999999));
        manager.renewSubdomain{value: 3.29 ether}(label, parentNamehash, renewalLength);

        (
            uint80 actualRegistrationTime,
            uint80 actualRegistrationLength, //uint96 actualRegistrationPrice

        ) = manager.subdomainRegistrationHistory(Namehash.getNamehash(parentNamehash, label));

        console.log("registration time", actualRegistrationTime);
        console.log("registration length", actualRegistrationLength);

        //check that the registration details have been updated.
        assertEq(
            actualRegistrationTime + actualRegistrationLength,
            registrationTimestamp + (registrationLength + renewalLength) * 1 days,
            "invalid registration details"
        );
    }

    function testRenewNoneExistingToken_fail() public {
        ILabelValidator validator = new MockLabelValidator(true);
        manager.updateLabelValidator(validator);
        setUpGlobalStrategy(true);

        bytes32 parentNamehash = bytes32(uint256(0x4));
        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);

        string memory label = "yo";
        bytes32 secret = 0x0;
        uint80 registrationLength = 500;
        uint80 renewalLength = 1200;

        address recipient = address(0x5555);

        startHoax(address(0x420), 20 ether);
        manager.registerSld{value: 2 ether}(
            label,
            secret,
            registrationLength,
            parentNamehash,
            recipient
        );

        vm.warp(block.timestamp + (registrationLength * 86400));

        vm.expectRevert("invalid domain");
        manager.renewSubdomain("doesnotexist", parentNamehash, renewalLength);

        vm.expectRevert("invalid domain");
        manager.renewSubdomain(
            label,
            keccak256(abi.encodePacked("doesnotexist")),
            registrationLength
        );
    }

    function testRenewExpiredSld_fail() public {
        ILabelValidator validator = new MockLabelValidator(true);
        manager.updateLabelValidator(validator);
        setUpGlobalStrategy(true);

        bytes32 parentNamehash = bytes32(uint256(0x4));
        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);

        string memory label = "yo";
        bytes32 secret = 0x0;
        uint80 registrationLength = 500;

        address recipient = address(0x5555);

        hoax(address(0x420), 20 ether);
        manager.registerSld{value: 2 ether}(
            label,
            secret,
            registrationLength,
            parentNamehash,
            recipient
        );

        vm.warp(block.timestamp + (registrationLength * 86400) + 1);

        vm.prank(address(0x420));
        vm.expectRevert("invalid domain");
        manager.renewSubdomain(label, parentNamehash, registrationLength);
    }

    function testRenewSldCheaperPriceInUpdatedRegistrationRules_useCheaperPrice(uint8 _years)
        public
    {
        _years = uint8(bound(_years, 1, 15));

        setUpLabelValidator();
        setUpGlobalStrategy(true);

        uint128[10] memory prices = [
            uint128(10 ether),
            9 ether,
            8 ether,
            7 ether,
            6 ether,
            5 ether,
            4 ether,
            3 ether,
            2 ether,
            1.5 ether
        ];

        uint128[15] memory cheapestPrices = [
            uint128(3 ether),
            3 ether,
            3 ether,
            3 ether,
            3 ether,
            3 ether,
            3 ether,
            3 ether,
            2 ether,
            1.5 ether,
            1.5 ether,
            1.5 ether,
            1.5 ether,
            1.5 ether,
            1.5 ether
        ];

        bytes32 parentNamehash = bytes32(uint256(0x55446677));
        tld.register(address(0x99), uint256(parentNamehash));

        MockRegistrationStrategy strategy = new MockRegistrationStrategy(3 ether);
        strategy.setMultiYearPricing(prices);
        sld.setMockRegistrationStrategy(parentNamehash, strategy);

        address sendingAddress = address(0x420);
        startHoax(sendingAddress, 100 ether);

        manager.registerSld{value: 10 ether}("yo", 0x0, 365, parentNamehash, address(0));

        bytes32 subdomainNamehash = Namehash.getNamehash(parentNamehash, "yo");

        // (
        //     uint80 actualRegistrationTime,
        //     uint80 actualRegistrationLength,
        //     uint96 actualRegistrationPrice
        // ) = manager.subdomainRegistrationHistory(subdomainNamehash);

        sld.setMockRegistrationStrategy(parentNamehash, new MockRegistrationStrategy(3 ether));

        sld.setNamehashToParentMap(subdomainNamehash, parentNamehash);

        //need to renew domain and then renew price should be cheapest price
        uint256 renewalPricePerDay = manager.getRenewalPricePerDay(
            parentNamehash,
            "yo",
            _years * 365
        );

        assertEq(renewalPricePerDay, cheapestPrices[_years - 1] / 365, "price incorrect");
    }

    function testGetDailyPricingForMultiYearDiscountStrategy() public {
        setUpLabelValidator();
        setUpGlobalStrategy(true);

        uint128[10] memory prices = [
            uint128(10 ether),
            9 ether,
            8 ether,
            7 ether,
            6 ether,
            5 ether,
            4 ether,
            3 ether,
            2 ether,
            1 ether
        ];

        string memory label = "yo";
        bytes32 secret = 0x0;
        uint80 registrationLength = 365;
        bytes32 parentNamehash = bytes32(uint256(0x55446677));

        tld.register(address(0x99), uint256(parentNamehash));

        MockRegistrationStrategy strategy = new MockRegistrationStrategy(1 ether); // $1 per year
        console.log("usdOracle", address(strategy));
        strategy.setMultiYearPricing(prices);
        sld.setMockRegistrationStrategy(parentNamehash, strategy);

        address recipient = address(0xbadbad);

        address sendingAddress = address(0x420);
        hoax(sendingAddress, 10.11 ether);
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

        vm.startPrank(sendingAddress);
        manager.registerSld{value: 10.11 ether}(
            label,
            secret,
            registrationLength,
            parentNamehash,
            recipient
        );

        assertEq(recipient.balance, 0.11 ether, "balance not correct");

        //assert
        for (uint256 i; i < 10; i++) {
            uint256 actual = manager.getRenewalPricePerDay(parentNamehash, label, (i + 1) * 365);

            uint256 expected = prices[i] / 365;

            assertGt(actual, 0);
            assertEq(actual, expected);
        }
    }

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

    function testPurchaseSingleDomainGetRefundForExcess() public {
        string memory label = "";
        uint256 registrationLength = 365 * 2;
        bytes32 parentNamehash = Namehash.getTldNamehash("yoyo");

        uint256 annualCost = 2000 ether; //should be $4000 total

        sld.setMockRegistrationStrategy(parentNamehash, new MockRegistrationStrategy(annualCost));

        setUpLabelValidator();
        setUpGlobalStrategy(true);
        addMockOracle();

        address claimant = address(0x6666);
        address tldOwner = address(0x464646);

        manager.updateHandshakePaymentAddress(address(0x57595351));

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.register(tldOwner, "yoyo");

        vm.warp(6688);
        uint256 registrationTimestamp = block.timestamp;

        hoax(claimant, 2 ether);
        manager.registerSld{value: 2 ether}( //should cost 2 ether
            label,
            0x0, //secret
            registrationLength,
            parentNamehash,
            claimant
        );
        vm.stopPrank();

        bytes32 namehash = Namehash.getNamehash(parentNamehash, label);

        (, uint80 RegistrationLength, ) = manager.subdomainRegistrationHistory(namehash);

        uint80 newRegLength = 400;

        vm.warp(block.timestamp + 420);
        hoax(claimant, 1.095 ether);
        vm.expectRevert("not enough ether");
        manager.renewSubdomain{value: 1.095 ether}(label, parentNamehash, newRegLength);

        hoax(claimant, 1.096 ether);

        manager.renewSubdomain{value: 1.096 ether}(label, parentNamehash, newRegLength);

        (
            uint80 NewRegistrationTime,
            uint80 NewRegistrationLength, //uint96NewRegistrationPrice

        ) = manager.subdomainRegistrationHistory(namehash);

        assertEq(
            NewRegistrationLength,
            RegistrationLength + (newRegLength * 86400),
            "new registrationLength not correct"
        );

        assertEq(
            NewRegistrationTime,
            registrationTimestamp,
            "original registration time incorrect"
        );
    }

    function testPurchaseSingleDomainFundsGetSentToOwnerAndHandshakeWallet() public {}

    function testSetHandshakeWalletAddressFromContractOwner_pass() public {}

    function testSetHandshakeWalletAddressToZeroAddressFromContractOwner_fail() public {}

    function testSetHandshakeWalletAddressFromNotContractOwner_fail() public {}
}

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

contract TestSldRegistrationManager is Test {
    SldRegistrationManager manager;
    using stdStorage for StdStorage;

    MockHandshakeSld sld;
    MockHandshakeTld tld;
    MockCommitIntent commitIntent;
    MockLabelValidator labelValidator;
    MockGlobalRegistrationStrategy globalStrategy;

    ISldRegistrationStrategy mockStrategy = new MockRegistrationStrategy(1 ether); // $1 per year

    fallback() external payable {}

    receive() external payable {}

    function setUp() public {
        labelValidator = new MockLabelValidator(true);
        sld = new MockHandshakeSld();
        tld = new MockHandshakeTld();
        commitIntent = new MockCommitIntent(true);
        MockUsdOracle oracle = new MockUsdOracle(100000000); //$1
        globalStrategy = new MockGlobalRegistrationStrategy(true, 1 ether);
        manager = new SldRegistrationManager();

        manager.init(
            tld,
            sld,
            commitIntent,
            oracle,
            labelValidator,
            globalStrategy,
            address(this),
            address(this)
        );
    }

    function addMockOracle() private {
        MockUsdOracle oracle = new MockUsdOracle(200000000000);
        stdstore.target(address(manager)).sig("usdOracle()").checked_write(address(oracle));
    }

    function setUpLabelValidator() public {
        ILabelValidator validator = new MockLabelValidator(true);
        manager.updateLabelValidator(validator);
    }

    function setUpGlobalStrategy(bool _result, uint256 _minPrice) public {
        IGlobalRegistrationRules globalRules = new MockGlobalRegistrationStrategy(
            _result,
            _minPrice
        );
        manager.updateGlobalRegistrationStrategy(globalRules);
    }

    function setUpRegistrationStrategy(bytes32 _parentNamehash) public {
        sld.setMockRegistrationStrategy(_parentNamehash, mockStrategy);
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
        setUpGlobalStrategy(true, 1 ether);

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

        IGlobalRegistrationRules rules = new MockGlobalRegistrationStrategy(false, 1 ether);
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
        setUpGlobalStrategy(true, 1 ether);

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
        setUpGlobalStrategy(true, 1 ether);

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
        IGlobalRegistrationRules globalRules = new MockGlobalRegistrationStrategy(false, 1 ether);
        manager.updateGlobalRegistrationStrategy(globalRules);

        assertEq(
            address(manager.globalStrategy()),
            address(globalRules),
            "global registration rules not set correctly"
        );
    }

    function testSetGlobalRegistrationStrategyFromNotContractOwner_fail() public {
        IGlobalRegistrationRules globalRules = new MockGlobalRegistrationStrategy(false, 1 ether);

        vm.startPrank(address(0x1234));
        vm.expectRevert("Ownable: caller is not the owner");
        manager.updateGlobalRegistrationStrategy(globalRules);
    }

    function testPurchaseSldToZeroAddress_expectSendToMsgSender() public {
        setUpLabelValidator();
        setUpGlobalStrategy(true, 1 ether);
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
            abi.encodeCall(manager.sld().registerSld, (sendingAddress, parentNamehash, label))
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
        setUpGlobalStrategy(true, 1 ether);
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
            abi.encodeCall(manager.sld().registerSld, (recipient, parentNamehash, label))
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

    function testPurchaseSldRegistrationDisabled_fail() public {
        setUpLabelValidator();
        setUpGlobalStrategy(true, 1 ether);
        bytes32 parentNamehash = bytes32(uint256(0x55446677));
        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);
        string memory label = "yo";
        bytes32 secret = 0x0;
        uint80 registrationLength = 500;

        address recipient = address(0xbadbad);

        stdstore.target(address(mockStrategy)).sig("isDisabledBool()").checked_write(true);

        address sendingAddress = address(0x420);
        hoax(sendingAddress, 2 ether);
        vm.expectRevert("registration strategy disabled");
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
        setUpGlobalStrategy(true, 1 ether);

        string memory label = "yo";
        bytes32 secret = 0x0;
        uint80 registrationLength = 500;
        bytes32 parentNamehash = bytes32(uint256(0x55446677));

        address recipient = address(0xbadbad);

        address sendingAddress = address(0x420);

        vm.prank(sendingAddress);
        vm.expectRevert("registration strategy does not support interface");
        manager.registerSld(label, secret, registrationLength, parentNamehash, recipient);
    }

    function testMintSingleDomainCheckHistory() public {
        setUpLabelValidator();
        setUpGlobalStrategy(true, 1 ether);

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
            abi.encodeCall(manager.sld().registerSld, (recipient, parentNamehash, label))
        );

        vm.startPrank(sendingAddress);
        manager.registerSld{value: 1 ether + 1}(
            label,
            secret,
            registrationLength,
            parentNamehash,
            recipient
        );

        bytes32 sldNamehash = Namehash.getNamehash(parentNamehash, label);

        (
            uint80 actualRegistrationTime,
            uint80 actualRegistrationLength,
            uint96 actualRegistrationPrice
        ) = manager.sldRegistrationHistory(sldNamehash);

        assertEq(actualRegistrationTime, block.timestamp, "registration time incorrect");
        assertEq(
            actualRegistrationLength,
            registrationLength * 1 days,
            "registration length incorrect"
        );
        assertEq(actualRegistrationPrice, 1 ether, "registration price incorrect");

        uint80[10] memory pricing = manager.getTenYearGuarenteedPricing(sldNamehash);

        for (uint256 i; i < 10; i++) {
            //pricing should return back flat rate of 1 dollar per year regardless of length
            assertEq(pricing[i], 1 ether, "issue with historic pricing");
        }
    }

    function testRenewSldFromSldOwner_pass() public {
        ILabelValidator validator = new MockLabelValidator(true);
        manager.updateLabelValidator(validator);
        setUpGlobalStrategy(true, 1 ether);

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

        manager.renewSld{value: 5 ether}(label, parentNamehash, renewalLength);

        (
            uint80 actualRegistrationTime,
            uint80 actualRegistrationLength, // uint96 actualRegistrationPrice

        ) = manager.sldRegistrationHistory(Namehash.getNamehash(parentNamehash, label));

        uint256 expectedValue = actualRegistrationTime + actualRegistrationLength;
        uint256 actualValue = block.timestamp + ((registrationLength + renewalLength) * 1 days);

        //check that the registration details have been updated.
        assertEq(actualValue, expectedValue, "invalid registration details");
    }

    //TODO: what's the expected behaviour (pass i think)
    function testRenewSldFromNotSldOwner_pass() public {
        ILabelValidator validator = new MockLabelValidator(true);
        manager.updateLabelValidator(validator);
        setUpGlobalStrategy(true, 1 ether);

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
        manager.renewSld{value: 3.29 ether}(label, parentNamehash, renewalLength);

        (
            uint80 actualRegistrationTime,
            uint80 actualRegistrationLength, //uint96 actualRegistrationPrice

        ) = manager.sldRegistrationHistory(Namehash.getNamehash(parentNamehash, label));

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
        setUpGlobalStrategy(true, 1 ether);

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
        manager.renewSld("doesnotexist", parentNamehash, renewalLength);

        vm.expectRevert("invalid domain");
        manager.renewSld(label, keccak256(abi.encodePacked("doesnotexist")), registrationLength);
    }

    function testRenewExpiredSld_fail() public {
        ILabelValidator validator = new MockLabelValidator(true);
        manager.updateLabelValidator(validator);
        setUpGlobalStrategy(true, 1 ether);

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
        manager.renewSld(label, parentNamehash, registrationLength);
    }

    function testRenewSldCheaperPriceInUpdatedRegistrationRules_useCheaperPrice(uint8 _years)
        public
    {
        _years = uint8(bound(_years, 1, 25));

        setUpLabelValidator();
        setUpGlobalStrategy(true, 1 ether);

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

        MockRegistrationStrategy strategy2 = new MockRegistrationStrategy(3 ether);
        strategy2.setMultiYearPricing(prices);
        sld.setMockRegistrationStrategy(parentNamehash, strategy2);

        tld.addRegistrationStrategy(parentNamehash, strategy2);

        address sendingAddress = address(0x420);
        startHoax(sendingAddress, 100 ether);

        manager.registerSld{value: 10 ether + 1}("yo", 0x0, 365, parentNamehash, address(0));

        bytes32 sldNamehash = Namehash.getNamehash(parentNamehash, "yo");

        MockRegistrationStrategy newStrategy = new MockRegistrationStrategy(3 ether);
        tld.addRegistrationStrategy(parentNamehash, newStrategy);

        sld.setMockRegistrationStrategy(parentNamehash, newStrategy);

        sld.setNamehashToParentMap(sldNamehash, parentNamehash);

        uint256 renewalPrice = manager.getRenewalPrice(
            msg.sender,
            parentNamehash,
            "yo",
            _years * 365
        ) / (_years * 365);

        // get the index of the cheapest price per year
        uint256 index = _years - 1 >= cheapestPrices.length
            ? cheapestPrices.length - 1
            : _years - 1;

        assertEq(renewalPrice, cheapestPrices[index] / 365, "price incorrect");
    }

    function testGetDailyPricingForMultiYearDiscountStrategy() public {
        setUpLabelValidator();
        setUpGlobalStrategy(true, 1 ether);

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

        MockRegistrationStrategy strategy2 = new MockRegistrationStrategy(1 ether); // $1 per year

        tld.addRegistrationStrategy(parentNamehash, strategy2);

        strategy2.setMultiYearPricing(prices);
        sld.setMockRegistrationStrategy(parentNamehash, strategy2);

        address recipient = address(0xbadbad);

        address sendingAddress = address(0x420);
        hoax(sendingAddress, 10.11 ether);
        vm.expectCall(
            address(manager.sld()),
            abi.encodeCall(manager.sld().registerSld, (recipient, parentNamehash, label))
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
            uint256 actual = manager.getRenewalPricePerDay(
                msg.sender,
                parentNamehash,
                label,
                (i + 1) * 365
            );

            uint256 expected = prices[i] / 365;

            assertGt(actual, 0);
            assertEq(actual, expected);
        }
    }

    //this test was crashing the test runner
    function testPurchaseSingleDomainGetRefundForExcess() public {
        string memory label = "";
        uint256 registrationLength = 365 * 2;
        bytes32 parentNamehash = Namehash.getTldNamehash("yoyo");

        uint256 annualCost = 2000 ether; //should be $4000 total

        ISldRegistrationStrategy strategy2 = new MockRegistrationStrategy(annualCost);

        sld.setMockRegistrationStrategy(parentNamehash, strategy2);
        tld.addRegistrationStrategy(parentNamehash, strategy2);

        setUpLabelValidator();
        setUpGlobalStrategy(true, 1 ether);
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

        hoax(claimant, 2 ether + 1);
        manager.registerSld{value: 2 ether + 1}( //should cost 2 ether
            label,
            0x0, //secret
            registrationLength,
            parentNamehash,
            claimant
        );
        vm.stopPrank();

        bytes32 namehash = Namehash.getNamehash(parentNamehash, label);

        (, uint80 RegistrationLength, ) = manager.sldRegistrationHistory(namehash);

        uint80 newRegLength = 400;

        vm.warp(block.timestamp + 420);
        hoax(claimant, 1.095 ether + 1);
        vm.expectRevert("not enough ether");
        manager.renewSld{value: 1.095 ether + 1}(label, parentNamehash, newRegLength);

        hoax(claimant, 1.096 ether + 1);

        manager.renewSld{value: 1.096 ether + 1}(label, parentNamehash, newRegLength);

        (
            uint80 NewRegistrationTime,
            uint80 NewRegistrationLength, //uint96NewRegistrationPrice

        ) = manager.sldRegistrationHistory(namehash);

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

    function testSetup50PercentReductionForAddressFromOwner_pass() public {
        string memory label = "foo";
        uint256 registrationLength = 365;
        bytes32 parentNamehash = Namehash.getTldNamehash("yoyo");

        uint256 annualCost = 2000 ether; //should be $4000 total

        tld.register(address(this), "yoyo");

        ISldRegistrationStrategy strategy2 = new MockRegistrationStrategy(annualCost);

        sld.setMockRegistrationStrategy(parentNamehash, strategy2);
        tld.addRegistrationStrategy(parentNamehash, strategy2);

        setUpLabelValidator();
        setUpGlobalStrategy(true, 1 ether);
        addMockOracle();

        address addr = address(0x225599);
        uint256 discount = 50;

        address[] memory arr1 = new address[](1);
        SldDiscountSettings[] memory arr2 = new SldDiscountSettings[](1);

        arr1[0] = addr;

        // uint80 startTimestamp;
        // uint80 endTimestamp;
        // uint8 discountPercentage;
        // bool isRegistration;
        // bool isRenewal;

        arr2[0] = SldDiscountSettings(0, type(uint80).max, 50, true, true);

        manager.setAddressDiscounts(parentNamehash, arr1, arr2);

        uint256 price = manager.getRegistrationPrice(
            strategy2,
            addr,
            parentNamehash,
            label,
            registrationLength
        );

        hoax(addr, price);
        manager.registerSld{value: price}(
            label,
            bytes32(uint256(555)),
            registrationLength,
            parentNamehash,
            addr
        );

        uint256 expected = annualCost / 2;
        assertEq(price, expected, "price should be 50% reduced");

        uint256 renewalPrice = manager.getRenewalPrice(
            addr,
            parentNamehash,
            label,
            registrationLength
        );

        assertEq(renewalPrice, price, "renewal price should be 50% reduced");
    }

    function testSetupMultipleReductionForAddressFromOwner_pass() public {
        string memory domain = "yoyo";

        bytes32 parentNamehash = Namehash.getTldNamehash(domain);

        uint256 annualCost = 2000 ether; //should be $4000 total

        tld.register(address(this), domain);

        ISldRegistrationStrategy strategy2 = new MockRegistrationStrategy(annualCost);

        sld.setMockRegistrationStrategy(parentNamehash, strategy2);
        tld.addRegistrationStrategy(parentNamehash, strategy2);

        setUpLabelValidator();
        setUpGlobalStrategy(true, 1 ether);
        addMockOracle();

        address[] memory arr1 = new address[](2);

        arr1[0] = address(0x225599);
        arr1[1] = address(0x225588);

        SldDiscountSettings[] memory arr2 = new SldDiscountSettings[](2);

        // uint80 startTimestamp;
        // uint80 endTimestamp;
        // uint8 discountPercentage;
        // bool isRegistration;
        // bool isRenewal;

        arr2[0] = SldDiscountSettings(0, type(uint80).max, 50, true, true);
        arr2[1] = SldDiscountSettings(0, type(uint80).max, 25, true, true);

        manager.setAddressDiscounts(parentNamehash, arr1, arr2);

        uint256 price = manager.getRegistrationPrice(
            strategy2,
            arr1[0],
            parentNamehash,
            "foo",
            365
        );

        hoax(arr1[0], price);
        manager.registerSld{value: price}(
            "foo",
            bytes32(uint256(555)),
            365,
            parentNamehash,
            arr1[0]
        );

        uint256 expected = annualCost / 2;
        assertEq(price, expected, "price should be 50% reduced");

        uint256 renewalPrice = manager.getRenewalPrice(arr1[0], parentNamehash, "foo", 365);
        assertEq(renewalPrice, price, "renewal price should be 50% reduced");

        sld.setMockRegistrationStrategy(parentNamehash, strategy2);
        tld.addRegistrationStrategy(parentNamehash, strategy2);
        uint256 price2 = manager.getRegistrationPrice(
            strategy2,
            arr1[1],
            parentNamehash,
            "bar",
            365
        );

        hoax(arr1[1], price2);
        manager.registerSld{value: price2}(
            "bar",
            bytes32(uint256(555)),
            365,
            parentNamehash,
            arr1[1]
        );

        uint256 expected2 = (annualCost / 4) * 3;
        assertEq(price2, expected2, "price should be 25% reduced");

        uint256 renewalPrice2 = manager.getRenewalPrice(arr1[1], parentNamehash, "bar", 365);
        assertEq(renewalPrice2, price2, "renewal price should be 25% reduced");
    }

    function testSetup100PercentReductionForAddressFromOwner_pass() public {
        string memory label = "foo";
        uint256 registrationLength = 365;
        bytes32 parentNamehash = Namehash.getTldNamehash("yoyo");

        uint256 annualCost = 2000 ether; //should be $4000 total

        tld.register(address(this), "yoyo");

        ISldRegistrationStrategy strategy2 = new MockRegistrationStrategy(annualCost);

        sld.setMockRegistrationStrategy(parentNamehash, strategy2);

        setUpLabelValidator();
        setUpGlobalStrategy(true, 1 ether);
        addMockOracle();

        address addr = address(0x225599);
        uint256 discount = 100;

        address[] memory arr1 = new address[](1);
        SldDiscountSettings[] memory arr2 = new SldDiscountSettings[](1);

        arr1[0] = addr;

        // uint80 startTimestamp;
        // uint80 endTimestamp;
        // uint8 discountPercentage;
        // bool isRegistration;
        // bool isRenewal;

        arr2[0] = SldDiscountSettings(0, type(uint80).max, 100, true, true);

        manager.setAddressDiscounts(parentNamehash, arr1, arr2);

        uint256 price = manager.getRegistrationPrice(
            strategy2,
            addr,
            parentNamehash,
            label,
            registrationLength
        );

        hoax(addr, price);
        manager.registerSld{value: price}(
            label,
            bytes32(uint256(555)),
            registrationLength,
            parentNamehash,
            addr
        );

        uint256 expected = 1 ether;
        assertEq(price, expected, "price should be $1");

        uint256 renewalPrice = manager.getRenewalPrice(
            addr,
            parentNamehash,
            label,
            registrationLength
        );

        assertEq(renewalPrice, price, "renewal price should be $1");
    }

    function testSetup100PercentReductionForAddressFromOwner_1to100years_pass(uint8 _years) public {
        uint256 renewalYears = bound(_years, 1, 100);
        string memory label = "foo";
        uint256 registrationLength = 365 * renewalYears;
        bytes32 parentNamehash = Namehash.getTldNamehash("yoyo");

        uint256 annualCost = 2000 ether; //should be $4000 total

        tld.register(address(this), "yoyo");

        ISldRegistrationStrategy strategy = new MockRegistrationStrategy(annualCost);

        sld.setMockRegistrationStrategy(parentNamehash, strategy);

        setUpLabelValidator();
        setUpGlobalStrategy(true, 1 ether);
        addMockOracle();

        address addr = address(0x225599);
        uint256 discount = 100;

        address[] memory arr1 = new address[](1);
        SldDiscountSettings[] memory arr2 = new SldDiscountSettings[](1);

        arr1[0] = addr;

        // uint80 startTimestamp;
        // uint80 endTimestamp;
        // uint8 discountPercentage;
        // bool isRegistration;
        // bool isRenewal;

        arr2[0] = SldDiscountSettings(0, type(uint80).max, 100, true, true);

        manager.setAddressDiscounts(parentNamehash, arr1, arr2);

        uint256 price = manager.getRegistrationPrice(
            strategy,
            addr,
            parentNamehash,
            label,
            registrationLength
        );

        hoax(addr, price);
        manager.registerSld{value: price}(
            label,
            bytes32(uint256(555)),
            registrationLength,
            parentNamehash,
            addr
        );

        uint256 expected = 1 ether;
        assertEq(price, expected * renewalYears, "price should be $1");

        uint256 renewalPrice = manager.getRenewalPrice(
            addr,
            parentNamehash,
            label,
            registrationLength
        );

        assertEq(renewalPrice, price, "renewal price should be $1");
    }

    function testSetupZeroPercentReductionForAddressFromOwner_pass() public {
        string memory label = "foo";
        uint256 registrationLength = 365;
        bytes32 parentNamehash = Namehash.getTldNamehash("yoyo");

        uint256 annualCost = 2000 ether; //should be $4000 total

        tld.register(address(this), "yoyo");

        ISldRegistrationStrategy strategy = new MockRegistrationStrategy(annualCost);

        sld.setMockRegistrationStrategy(parentNamehash, strategy);
        tld.addRegistrationStrategy(parentNamehash, strategy);

        setUpLabelValidator();
        setUpGlobalStrategy(true, 1 ether);
        addMockOracle();

        address addr = address(0x225599);
        uint256 discount = 0;

        address[] memory arr1 = new address[](1);
        SldDiscountSettings[] memory arr2 = new SldDiscountSettings[](1);

        arr1[0] = addr;

        // uint80 startTimestamp;
        // uint80 endTimestamp;
        // uint8 discountPercentage;
        // bool isRegistration;
        // bool isRenewal;

        arr2[0] = SldDiscountSettings(0, type(uint80).max, 0, true, true);

        manager.setAddressDiscounts(parentNamehash, arr1, arr2);

        uint256 price = manager.getRegistrationPrice(
            strategy,
            addr,
            parentNamehash,
            label,
            registrationLength
        );

        hoax(addr, price);
        manager.registerSld{value: price}(
            label,
            bytes32(uint256(555)),
            registrationLength,
            parentNamehash,
            addr
        );

        uint256 expected = annualCost;
        assertEq(price, expected, "price should be $2000");

        uint256 renewalPrice = manager.getRenewalPrice(
            addr,
            parentNamehash,
            label,
            registrationLength
        );

        assertEq(renewalPrice, price, "renewal price should be $2000");
    }

    function testSetup100PercentReductionForAddressRenewFromOtherAdressShouldBeFullPrice_pass()
        public
    {
        string memory label = "foo";
        uint256 registrationLength = 365;
        bytes32 parentNamehash = Namehash.getTldNamehash("yoyo");

        uint256 annualCost = 2000 ether; //should be $4000 total

        tld.register(address(this), "yoyo");

        ISldRegistrationStrategy strategy = new MockRegistrationStrategy(annualCost);

        sld.setMockRegistrationStrategy(parentNamehash, strategy);
        tld.addRegistrationStrategy(parentNamehash, strategy);

        setUpLabelValidator();
        setUpGlobalStrategy(true, 1 ether);
        addMockOracle();

        address addr = address(0x225599);
        uint256 discount = 100;

        address[] memory arr1 = new address[](1);
        SldDiscountSettings[] memory arr2 = new SldDiscountSettings[](1);

        arr1[0] = addr;

        // uint80 startTimestamp;
        // uint80 endTimestamp;
        // uint8 discountPercentage;
        // bool isRegistration;
        // bool isRenewal;

        arr2[0] = SldDiscountSettings(0, type(uint80).max, 100, true, true);

        manager.setAddressDiscounts(parentNamehash, arr1, arr2);

        uint256 price = manager.getRegistrationPrice(
            strategy,
            addr,
            parentNamehash,
            label,
            registrationLength
        );

        hoax(addr, price);
        manager.registerSld{value: price}(
            label,
            bytes32(uint256(555)),
            registrationLength,
            parentNamehash,
            addr
        );

        uint256 expected = 1 ether;
        assertEq(price, expected, "price should be $1");

        uint256 renewalPrice = manager.getRenewalPrice(
            address(0xbada55),
            parentNamehash,
            label,
            registrationLength
        );

        assertEq(renewalPrice, annualCost, "renewal price should be full cost");
    }

    function testSetup100PercentReductionWithStartTimestampInFuture_pass() public {
        string memory label = "foo";
        uint256 registrationLength = 365;
        bytes32 parentNamehash = Namehash.getTldNamehash("yoyo");

        uint256 annualCost = 2000 ether; //should be $4000 total

        tld.register(address(this), "yoyo");

        ISldRegistrationStrategy strategy = new MockRegistrationStrategy(annualCost);

        sld.setMockRegistrationStrategy(parentNamehash, strategy);
        tld.addRegistrationStrategy(parentNamehash, strategy);

        setUpLabelValidator();
        setUpGlobalStrategy(true, 1 ether);
        addMockOracle();

        address addr = address(0x225599);
        uint256 discount = 100;

        address[] memory arr1 = new address[](1);
        SldDiscountSettings[] memory arr2 = new SldDiscountSettings[](1);

        arr1[0] = addr;

        // uint80 startTimestamp;
        // uint80 endTimestamp;
        // uint8 discountPercentage;
        // bool isRegistration;
        // bool isRenewal;

        uint80 start = uint80(block.timestamp + 1 days);

        vm.warp(start);

        arr2[0] = SldDiscountSettings(start + 50, type(uint80).max, 0, true, true);

        manager.setAddressDiscounts(parentNamehash, arr1, arr2);

        uint256 price = manager.getRegistrationPrice(
            strategy,
            addr,
            parentNamehash,
            label,
            registrationLength
        );

        hoax(addr, price + 1);
        manager.registerSld{value: price}(
            label,
            bytes32(uint256(555)),
            registrationLength,
            parentNamehash,
            addr
        );

        assertEq(price, annualCost, "registration should be at full cost");

        uint256 renewalPrice = manager.getRenewalPrice(
            addr,
            parentNamehash,
            label,
            registrationLength
        );

        assertEq(renewalPrice, annualCost, "renewal price should be full cost");
    }

    function testSetup100PercentReductionWithStartTimestampInPast_pass() public {
        string memory label = "foo";
        uint256 registrationLength = 365;
        bytes32 parentNamehash = Namehash.getTldNamehash("yoyo");

        uint256 annualCost = 2000 ether; //should be $4000 total

        tld.register(address(this), "yoyo");

        ISldRegistrationStrategy strategy = new MockRegistrationStrategy(annualCost);

        sld.setMockRegistrationStrategy(parentNamehash, strategy);
        tld.addRegistrationStrategy(parentNamehash, strategy);

        setUpLabelValidator();
        setUpGlobalStrategy(true, 1 ether);
        addMockOracle();

        address addr = address(0x225599);
        uint256 discount = 100;

        address[] memory arr1 = new address[](1);
        SldDiscountSettings[] memory arr2 = new SldDiscountSettings[](1);

        arr1[0] = addr;

        // uint80 startTimestamp;
        // uint80 endTimestamp;
        // uint8 discountPercentage;
        // bool isRegistration;
        // bool isRenewal;

        uint80 start = uint80(block.timestamp + 1 days);

        vm.warp(start);

        arr2[0] = SldDiscountSettings(start - 50, type(uint80).max, 100, true, true);

        manager.setAddressDiscounts(parentNamehash, arr1, arr2);

        uint256 price = manager.getRegistrationPrice(
            strategy,
            addr,
            parentNamehash,
            label,
            registrationLength
        );

        hoax(addr, price + 1);
        manager.registerSld{value: price}(
            label,
            bytes32(uint256(555)),
            registrationLength,
            parentNamehash,
            addr
        );

        assertEq(price, 1 ether, "registration should be at full cost");

        uint256 renewalPrice = manager.getRenewalPrice(
            addr,
            parentNamehash,
            label,
            registrationLength
        );

        assertEq(renewalPrice, 1 ether, "renewal price should be full cost");
    }

    function testSetup100PercentReductionWithStartTimestampInPastOnlyRegistration_pass() public {
        string memory label = "foo";
        uint256 registrationLength = 365;
        bytes32 parentNamehash = Namehash.getTldNamehash("yoyo");

        uint256 annualCost = 2000 ether; //should be $4000 total

        tld.register(address(this), "yoyo");

        ISldRegistrationStrategy strategy = new MockRegistrationStrategy(annualCost);

        sld.setMockRegistrationStrategy(parentNamehash, strategy);
        tld.addRegistrationStrategy(parentNamehash, strategy);

        setUpLabelValidator();
        setUpGlobalStrategy(true, 1 ether);
        addMockOracle();

        address addr = address(0x225599);
        uint256 discount = 100;

        address[] memory arr1 = new address[](1);
        SldDiscountSettings[] memory arr2 = new SldDiscountSettings[](1);

        arr1[0] = addr;

        // uint80 startTimestamp;
        // uint80 endTimestamp;
        // uint8 discountPercentage;
        // bool isRegistration;
        // bool isRenewal;

        uint80 start = uint80(block.timestamp + 1 days);

        vm.warp(start);

        arr2[0] = SldDiscountSettings(start - 50, type(uint80).max, 100, true, false);

        manager.setAddressDiscounts(parentNamehash, arr1, arr2);

        uint256 price = manager.getRegistrationPrice(
            strategy,
            addr,
            parentNamehash,
            label,
            registrationLength
        );

        hoax(addr, price + 1);
        manager.registerSld{value: price}(
            label,
            bytes32(uint256(555)),
            registrationLength,
            parentNamehash,
            addr
        );

        assertEq(price, 1 ether, "registration should be at full cost");

        uint256 renewalPrice = manager.getRenewalPrice(
            addr,
            parentNamehash,
            label,
            registrationLength
        );

        assertEq(renewalPrice, annualCost, "renewal price should be full cost");
    }

    function testSetup100PercentReductionWithStartTimestampInPastOnlyRenewal_pass() public {
        string memory label = "foo";
        uint256 registrationLength = 365;
        bytes32 parentNamehash = Namehash.getTldNamehash("yoyo");

        uint256 annualCost = 2000 ether; //should be $4000 total

        tld.register(address(this), "yoyo");

        ISldRegistrationStrategy strategy = new MockRegistrationStrategy(annualCost);

        sld.setMockRegistrationStrategy(parentNamehash, strategy);
        tld.addRegistrationStrategy(parentNamehash, strategy);

        setUpLabelValidator();
        setUpGlobalStrategy(true, 1 ether);
        addMockOracle();

        address addr = address(0x225599);
        uint256 discount = 100;

        address[] memory arr1 = new address[](1);
        SldDiscountSettings[] memory arr2 = new SldDiscountSettings[](1);

        arr1[0] = addr;

        // uint80 startTimestamp;
        // uint80 endTimestamp;
        // uint8 discountPercentage;
        // bool isRegistration;
        // bool isRenewal;

        uint80 start = uint80(block.timestamp + 1 days);

        vm.warp(start);

        arr2[0] = SldDiscountSettings(start - 50, type(uint80).max, 100, false, true);

        manager.setAddressDiscounts(parentNamehash, arr1, arr2);

        uint256 price = manager.getRegistrationPrice(
            strategy,
            addr,
            parentNamehash,
            label,
            registrationLength
        );

        hoax(addr, price + 1);
        manager.registerSld{value: price}(
            label,
            bytes32(uint256(555)),
            registrationLength,
            parentNamehash,
            addr
        );

        assertEq(price, annualCost, "registration should be at full cost");

        uint256 renewalPrice = manager.getRenewalPrice(
            addr,
            parentNamehash,
            label,
            registrationLength
        );

        uint256 expected = 1 ether;
        assertEq(renewalPrice, expected, "renewal price should be full cost");
    }

    function testSetupWildcardReduction_pass() public {
        string memory label = "foo";
        uint256 registrationLength = 365;
        bytes32 parentNamehash = Namehash.getTldNamehash("yoyo");

        uint256 annualCost = 2000 ether; //should be $4000 total

        tld.register(address(this), "yoyo");

        ISldRegistrationStrategy strategy = new MockRegistrationStrategy(annualCost);

        sld.setMockRegistrationStrategy(parentNamehash, strategy);
        tld.addRegistrationStrategy(parentNamehash, strategy);

        setUpLabelValidator();
        setUpGlobalStrategy(true, 1 ether);
        addMockOracle();

        address addr = address(0x225599);
        uint256 discount = 100;

        address[] memory arr1 = new address[](1);
        SldDiscountSettings[] memory arr2 = new SldDiscountSettings[](1);

        arr1[0] = address(0); // address(0) is a wildcard

        // uint80 startTimestamp;
        // uint80 endTimestamp;
        // uint8 discountPercentage;
        // bool isRegistration;
        // bool isRenewal;

        uint80 start = uint80(block.timestamp + 1 days);

        vm.warp(start);

        arr2[0] = SldDiscountSettings(start + 10, start + 30, 50, true, false);

        manager.setAddressDiscounts(parentNamehash, arr1, arr2);

        uint256 price = manager.getRegistrationPrice(
            strategy,
            addr,
            parentNamehash,
            label,
            registrationLength
        );

        assertEq(price, annualCost, "registration should be at full cost"); //not started yet

        vm.warp(start + 20);

        price = manager.getRegistrationPrice(
            strategy,
            addr,
            parentNamehash,
            label,
            registrationLength
        );

        assertEq(price, annualCost / 2, "registration should be 50% cost"); //started now

        vm.warp(start + 40);

        price = manager.getRegistrationPrice(
            strategy,
            addr,
            parentNamehash,
            label,
            registrationLength
        );

        assertEq(price, annualCost, "registration should be at full cost"); //completed now

        hoax(addr, price + 1);
        manager.registerSld{value: price}(
            label,
            bytes32(uint256(555)),
            registrationLength,
            parentNamehash,
            addr
        );

        uint256 renewalPrice = manager.getRenewalPrice(
            addr,
            parentNamehash,
            label,
            registrationLength
        );

        assertEq(renewalPrice, annualCost, "renewal price should be full cost"); //renewal is not discounted

        arr2[0] = SldDiscountSettings(start + 50, start + 70, 75, false, true);

        //set a new discount for renewals
        manager.setAddressDiscounts(parentNamehash, arr1, arr2);

        vm.warp(start + 60);

        renewalPrice = manager.getRenewalPrice(addr, parentNamehash, label, registrationLength);

        assertEq(renewalPrice, annualCost / 4, "renewal price should be 25% cost"); //renewal is discounted

        vm.warp(start + 80);

        renewalPrice = manager.getRenewalPrice(addr, parentNamehash, label, registrationLength);

        assertEq(renewalPrice, annualCost, "renewal price should be full cost"); //renewal discount has ended
    }

    function testSetupPercentReductionWithMultipleDiscountsFromDifferentWallets_pass() public {
        string memory label = "foo";
        uint256 registrationLength = 365;
        bytes32 parentNamehash = Namehash.getTldNamehash("yoyo");

        uint256 annualCost = 100 ether;

        tld.register(address(this), "yoyo");

        ISldRegistrationStrategy strategy = new MockRegistrationStrategy(annualCost);

        sld.setMockRegistrationStrategy(parentNamehash, strategy);
        tld.addRegistrationStrategy(parentNamehash, strategy);

        setUpLabelValidator();
        setUpGlobalStrategy(true, 1 ether);
        addMockOracle();

        uint256 discount = 100;

        address[] memory arr1 = new address[](5);
        SldDiscountSettings[] memory arr2 = new SldDiscountSettings[](5);

        arr1[0] = address(0x1);
        arr1[1] = address(0x2);
        arr1[2] = address(0x3);
        arr1[3] = address(0x4);
        arr1[4] = address(0x5);

        // uint80 startTimestamp;
        // uint80 endTimestamp;
        // uint8 discountPercentage;
        // bool isRegistration;
        // bool isRenewal;

        uint80 start = uint80(block.timestamp + 1 days);

        vm.warp(start);

        arr2[0] = SldDiscountSettings(start - 50, type(uint80).max, 50, false, true);
        arr2[1] = SldDiscountSettings(start - 50, start + 20, 25, false, true);
        arr2[2] = SldDiscountSettings(start + 10, start + 20, 75, false, true);
        arr2[3] = SldDiscountSettings(start - 50, type(uint80).max, 98, false, true);
        arr2[4] = SldDiscountSettings(start - 50, type(uint80).max, 100, false, true);

        manager.setAddressDiscounts(parentNamehash, arr1, arr2);

        uint256 price = manager.getRegistrationPrice(
            strategy,
            arr1[0],
            parentNamehash,
            label,
            registrationLength
        );

        assertEq(price, 100 ether, "registration should be full price");

        hoax(arr1[0], price);
        manager.registerSld{value: price}(
            label,
            bytes32(uint256(555)),
            registrationLength,
            parentNamehash,
            arr1[0]
        );

        price = manager.getRenewalPrice(arr1[0], parentNamehash, label, registrationLength);

        assertEq(price, 50 ether, "renewal should 50% reduced");

        price = manager.getRenewalPrice(arr1[1], parentNamehash, label, registrationLength);

        assertEq(price, 75 ether, "renewal should 25% reduced");

        price = manager.getRenewalPrice(arr1[2], parentNamehash, label, registrationLength);

        assertEq(price, 100 ether, "renewal should be at full cost");

        price = manager.getRenewalPrice(arr1[3], parentNamehash, label, registrationLength);

        assertEq(price, 2 ether, "renewal should be 98% reduced");

        price = manager.getRenewalPrice(arr1[4], parentNamehash, label, registrationLength);

        assertEq(price, 1 ether, "renewal should be 100% reduced but min is $1");

        vm.warp(start + 15);

        price = manager.getRenewalPrice(arr1[0], parentNamehash, label, registrationLength);

        assertEq(price, 50 ether, "renewal should be 50% reduced");

        price = manager.getRenewalPrice(arr1[1], parentNamehash, label, registrationLength);

        assertEq(price, 75 ether, "renewal should 25% reduced");

        price = manager.getRenewalPrice(arr1[2], parentNamehash, label, registrationLength);

        assertEq(price, 25 ether, "renewal should be 75% reduced");

        price = manager.getRenewalPrice(arr1[3], parentNamehash, label, registrationLength);

        assertEq(price, 2 ether, "renewal should be 98% reduced");

        price = manager.getRenewalPrice(arr1[4], parentNamehash, label, registrationLength);

        assertEq(price, 1 ether, "renewal should be 100% reduced but min is $1");

        vm.warp(start + 25);

        price = manager.getRenewalPrice(arr1[0], parentNamehash, label, registrationLength);

        assertEq(price, 50 ether, "renewal should be 50% reduced");

        price = manager.getRenewalPrice(arr1[1], parentNamehash, label, registrationLength);

        assertEq(price, 100 ether, "renewal should full price");

        price = manager.getRenewalPrice(arr1[2], parentNamehash, label, registrationLength);

        assertEq(price, 100 ether, "renewal should be at full cost");

        price = manager.getRenewalPrice(arr1[3], parentNamehash, label, registrationLength);

        assertEq(price, 2 ether, "renewal should be 98% reduced");

        price = manager.getRenewalPrice(arr1[4], parentNamehash, label, registrationLength);

        assertEq(price, 1 ether, "renewal should be 100% reduced but min is $1");
    }

    function testSetupPercentReductionWithMultipleDiscountsRenewalsFromDifferentWallets_pass()
        public
    {
        string memory label = "foo";
        uint256 registrationLength = 365;
        bytes32 parentNamehash = Namehash.getTldNamehash("yoyo");

        uint256 annualCost = 100 ether;

        tld.register(address(this), "yoyo");

        ISldRegistrationStrategy strategy = new MockRegistrationStrategy(annualCost);

        sld.setMockRegistrationStrategy(parentNamehash, strategy);
        tld.addRegistrationStrategy(parentNamehash, strategy);

        setUpLabelValidator();
        setUpGlobalStrategy(true, 1 ether);
        addMockOracle();

        uint256 discount = 100;

        address[] memory arr1 = new address[](5);
        SldDiscountSettings[] memory arr2 = new SldDiscountSettings[](5);

        arr1[0] = address(0x1);
        arr1[1] = address(0x2);
        arr1[2] = address(0x3);
        arr1[3] = address(0x4);
        arr1[4] = address(0x5);

        // uint80 startTimestamp;
        // uint80 endTimestamp;
        // uint8 discountPercentage;
        // bool isRegistration;
        // bool isRenewal;

        uint80 start = uint80(block.timestamp + 1 days);

        vm.warp(start);

        arr2[0] = SldDiscountSettings(start - 50, type(uint80).max, 50, false, true);
        arr2[1] = SldDiscountSettings(start - 50, start + 20, 25, false, true);
        arr2[2] = SldDiscountSettings(start + 10, start + 20, 75, false, true);
        arr2[3] = SldDiscountSettings(start - 50, type(uint80).max, 98, false, true);
        arr2[4] = SldDiscountSettings(start - 50, type(uint80).max, 100, false, true);

        manager.setAddressDiscounts(parentNamehash, arr1, arr2);

        uint256 price = manager.getRegistrationPrice(
            strategy,
            arr1[0],
            parentNamehash,
            label,
            registrationLength
        );

        hoax(arr1[0], price);
        manager.registerSld{value: price}(
            label,
            bytes32(uint256(555)),
            registrationLength,
            parentNamehash,
            arr1[0]
        );

        price = manager.getRenewalPrice(arr1[0], parentNamehash, label, registrationLength);

        assertEq(price, 50 ether, "registration should be 50% reduced");

        price = manager.getRenewalPrice(arr1[1], parentNamehash, label, registrationLength);

        assertEq(price, 75 ether, "registration should 25% reduced");

        price = manager.getRenewalPrice(arr1[2], parentNamehash, label, registrationLength);

        assertEq(price, 100 ether, "registration should be at full cost");

        price = manager.getRenewalPrice(arr1[3], parentNamehash, label, registrationLength);

        assertEq(price, 2 ether, "registration should be 98% reduced");

        price = manager.getRenewalPrice(arr1[4], parentNamehash, label, registrationLength);

        assertEq(price, 1 ether, "registration should be 100% reduced but min is $1");

        vm.warp(start + 15);

        price = manager.getRenewalPrice(arr1[0], parentNamehash, label, registrationLength);

        assertEq(price, 50 ether, "registration should be 50% reduced");

        price = manager.getRenewalPrice(arr1[1], parentNamehash, label, registrationLength);

        assertEq(price, 75 ether, "registration should 25% reduced");

        price = manager.getRenewalPrice(arr1[2], parentNamehash, label, registrationLength);

        assertEq(price, 25 ether, "registration should be 75% reduced");

        price = manager.getRenewalPrice(arr1[3], parentNamehash, label, registrationLength);

        assertEq(price, 2 ether, "registration should be 98% reduced");

        price = manager.getRenewalPrice(arr1[4], parentNamehash, label, registrationLength);

        assertEq(price, 1 ether, "registration should be 100% reduced but min is $1");

        vm.warp(start + 25);

        price = manager.getRenewalPrice(arr1[0], parentNamehash, label, registrationLength);

        assertEq(price, 50 ether, "registration should be 50% reduced");

        price = manager.getRenewalPrice(arr1[1], parentNamehash, label, registrationLength);

        assertEq(price, 100 ether, "registration should full price");

        price = manager.getRenewalPrice(arr1[2], parentNamehash, label, registrationLength);

        assertEq(price, 100 ether, "registration should be at full cost");

        price = manager.getRenewalPrice(arr1[3], parentNamehash, label, registrationLength);

        assertEq(price, 2 ether, "registration should be 98% reduced");

        price = manager.getRenewalPrice(arr1[4], parentNamehash, label, registrationLength);

        assertEq(price, 1 ether, "registration should be 100% reduced but min is $1");
    }

    function testSetup100PercentReductionForAddressFromApprovedAddress_pass() public {
        bytes32 parentNamehash = Namehash.getTldNamehash("yoyo");

        uint256 annualCost = 2000 ether; //should be $4000 total

        tld.register(address(this), "yoyo");

        address approved = address(0x123456);

        tld.setApprovalForAll(approved, true);

        ISldRegistrationStrategy strategy = new MockRegistrationStrategy(annualCost);

        sld.setMockRegistrationStrategy(parentNamehash, strategy);

        setUpLabelValidator();
        setUpGlobalStrategy(true, 1 ether);
        addMockOracle();

        address addr = address(0x225599);
        uint256 discount = 100;

        address[] memory arr1 = new address[](1);
        SldDiscountSettings[] memory arr2 = new SldDiscountSettings[](1);

        arr1[0] = addr;

        // uint80 startTimestamp;
        // uint80 endTimestamp;
        // uint8 discountPercentage;
        // bool isRegistration;
        // bool isRenewal;

        arr2[0] = SldDiscountSettings(0, type(uint80).max, 0, true, true);

        vm.prank(approved);
        manager.setAddressDiscounts(parentNamehash, arr1, arr2);
    }

    function testSetup100PercentReductionForAddressFromNotApprovedAddress_fail() public {
        bytes32 parentNamehash = Namehash.getTldNamehash("yoyo");

        uint256 annualCost = 2000 ether;

        tld.register(address(this), "yoyo");

        address not_approved = address(0x123456);

        ISldRegistrationStrategy strategy = new MockRegistrationStrategy(annualCost);

        sld.setMockRegistrationStrategy(parentNamehash, strategy);

        setUpLabelValidator();
        setUpGlobalStrategy(true, 1 ether);
        addMockOracle();

        address addr = address(0x225599);
        uint256 discount = 100;

        address[] memory arr1 = new address[](1);
        SldDiscountSettings[] memory arr2 = new SldDiscountSettings[](1);

        arr1[0] = addr;

        // uint80 startTimestamp;
        // uint80 endTimestamp;
        // uint8 discountPercentage;
        // bool isRegistration;
        // bool isRenewal;

        arr2[0] = SldDiscountSettings(0, 0, 0, true, true);

        vm.prank(not_approved);
        vm.expectRevert("not approved or owner");
        manager.setAddressDiscounts(parentNamehash, arr1, arr2);
    }

    //this is a test to avoid gas griefing
    function testSetup100PercentReductionRenewWithRevertingPriceStrategy_pass() public {
        string memory label = "foo";
        uint256 registrationLength = 365;
        bytes32 parentNamehash = Namehash.getTldNamehash("yoyo");

        uint256 annualCost = 2000 ether; //should be $4000 total

        tld.register(address(this), "yoyo");

        ISldRegistrationStrategy strategy = new MockRegistrationStrategy(annualCost);

        sld.setMockRegistrationStrategy(parentNamehash, strategy);

        setUpLabelValidator();
        setUpGlobalStrategy(true, 1 ether);
        globalStrategy = new MockGlobalRegistrationStrategy(true, 1 ether);
        addMockOracle();

        address addr = address(0x225599);
        uint256 discount = 100;

        address[] memory arr1 = new address[](1);
        SldDiscountSettings[] memory arr2 = new SldDiscountSettings[](1);

        arr1[0] = addr;

        // uint80 startTimestamp;
        // uint80 endTimestamp;
        // uint8 discountPercentage;
        // bool isRegistration;
        // bool isRenewal;

        arr2[0] = SldDiscountSettings(0, type(uint80).max, 100, true, true);

        manager.setAddressDiscounts(parentNamehash, arr1, arr2);

        uint256 price = manager.getRegistrationPrice(
            strategy,
            addr,
            parentNamehash,
            label,
            registrationLength
        );

        hoax(addr, price);
        manager.registerSld{value: price}(
            label,
            bytes32(uint256(555)),
            registrationLength,
            parentNamehash,
            addr
        );

        sld.setMockRegistrationStrategy(
            parentNamehash,
            new MockGasLimitRegistrationStrategy(50000000)
        );

        assertEq(price, 1 ether, "price should be $1");

        uint256 renewalPrice = manager.getRenewalPrice{gas: 30000000}(
            addr,
            parentNamehash,
            label,
            registrationLength
        );

        assertEq(renewalPrice, price, "renewal price should be $1");
    }

    function testSetup100PercentReductionWithRevertingPriceStrategy_pass() public {
        string memory label = "foo";
        uint256 registrationLength = 365;
        bytes32 parentNamehash = Namehash.getTldNamehash("yoyo");

        uint256 annualCost = 2000 ether; //should be $4000 total

        tld.register(address(this), "yoyo");

        ISldRegistrationStrategy strategy = new MockRegistrationStrategy(annualCost);

        sld.setMockRegistrationStrategy(parentNamehash, strategy);

        setUpLabelValidator();
        setUpGlobalStrategy(true, 1 ether);
        addMockOracle();

        address addr = address(0x225599);
        uint256 discount = 100;

        address[] memory arr1 = new address[](1);
        SldDiscountSettings[] memory arr2 = new SldDiscountSettings[](1);

        arr1[0] = addr;

        // uint80 startTimestamp;
        // uint80 endTimestamp;
        // uint8 discountPercentage;
        // bool isRegistration;
        // bool isRenewal;

        arr2[0] = SldDiscountSettings(0, type(uint80).max, 100, true, true);

        manager.setAddressDiscounts(parentNamehash, arr1, arr2);

        uint256 price = manager.getRegistrationPrice(
            strategy,
            addr,
            parentNamehash,
            label,
            registrationLength
        );

        hoax(addr, price);
        manager.registerSld{value: price}(
            label,
            bytes32(uint256(555)),
            registrationLength,
            parentNamehash,
            addr
        );

        uint256 expected = 1 ether;
        assertEq(price, expected, "price should be $1");

        uint256 renewalPrice = manager.getRenewalPrice(
            addr,
            parentNamehash,
            label,
            registrationLength
        );

        assertEq(renewalPrice, price, "renewal price should be $1");
    }

    function testHighGasUsagePriceStrategy() public {
        MockGasLimitRegistrationStrategy strategy = new MockGasLimitRegistrationStrategy(250000000);

        string memory label = "foo";
        uint256 registrationLength = 365;
        bytes32 parentNamehash = Namehash.getTldNamehash("yoyo");

        tld.register(address(this), "yoyo");

        sld.setMockRegistrationStrategy(parentNamehash, strategy);

        setUpLabelValidator();
        setUpGlobalStrategy(true, 1 ether);
        addMockOracle();

        address addr = address(0x225599);
        uint256 discount = 0;

        address[] memory arr1 = new address[](1);
        SldDiscountSettings[] memory arr2 = new SldDiscountSettings[](1);

        arr1[0] = addr;

        // uint80 startTimestamp;
        // uint80 endTimestamp;
        // uint8 discountPercentage;
        // bool isRegistration;
        // bool isRenewal;

        arr2[0] = SldDiscountSettings(0, type(uint80).max, 0, true, true);

        manager.setAddressDiscounts(parentNamehash, arr1, arr2);

        uint256 price = manager.getRegistrationPrice{gas: 2000000}(
            strategy,
            addr,
            parentNamehash,
            label,
            registrationLength
        );

        assertEq(price, 1 ether, "price should be $1");
    }

    function testRevertingPriceStrategy() public {
        MockRevertingRegistrationStrategy strategy = new MockRevertingRegistrationStrategy();

        string memory label = "foo";
        uint256 registrationLength = 365;
        bytes32 parentNamehash = Namehash.getTldNamehash("yoyo");

        tld.register(address(this), "yoyo");

        sld.setMockRegistrationStrategy(parentNamehash, strategy);

        setUpLabelValidator();
        setUpGlobalStrategy(true, 1 ether);
        addMockOracle();

        address addr = address(0x225599);
        uint256 discount = 0;

        address[] memory arr1 = new address[](1);
        SldDiscountSettings[] memory arr2 = new SldDiscountSettings[](1);

        arr1[0] = addr;

        // uint80 startTimestamp;
        // uint80 endTimestamp;
        // uint8 discountPercentage;
        // bool isRegistration;
        // bool isRenewal;

        arr2[0] = SldDiscountSettings(0, 0, 0, true, true);

        manager.setAddressDiscounts(parentNamehash, arr1, arr2);

        uint256 price = manager.getRegistrationPrice(
            strategy,
            addr,
            parentNamehash,
            label,
            registrationLength * 2
        );

        assertEq(price, 2 ether, "price should be $2");
    }

    function testInvalidPriceStrategy() public {
        uint256 annualCost = 2000 ether;
        ISldRegistrationStrategy strategy2 = new MockRegistrationStrategy(annualCost);

        string memory label = "foo";
        uint256 registrationLength = 365;
        bytes32 parentNamehash = Namehash.getTldNamehash("yoyo");

        tld.register(address(this), "yoyo");

        sld.setMockRegistrationStrategy(parentNamehash, strategy2);

        setUpLabelValidator();
        setUpGlobalStrategy(true, 1 ether);
        addMockOracle();

        address addr = address(0x225599);
        uint256 discount = 0;

        address[] memory arr1 = new address[](1);
        SldDiscountSettings[] memory arr2 = new SldDiscountSettings[](1);

        arr1[0] = addr;

        // uint80 startTimestamp;
        // uint80 endTimestamp;
        // uint8 discountPercentage;
        // bool isRegistration;
        // bool isRenewal;

        arr2[0] = SldDiscountSettings(0, type(uint80).max, 0, true, true);

        manager.setAddressDiscounts(parentNamehash, arr1, arr2);

        uint256 price = manager.getRegistrationPrice(
            strategy2,
            addr,
            parentNamehash,
            label,
            registrationLength
        );

        assertEq(price, annualCost, "price should be $2000");

        hoax(addr, price);
        manager.registerSld{value: price}(
            label,
            bytes32(uint256(555)),
            registrationLength,
            parentNamehash,
            addr
        );

        sld.setMockRegistrationStrategy(
            parentNamehash,
            ISldRegistrationStrategy(address(0x888888))
        );

        uint256 renewalPrice = manager.getRenewalPrice(
            addr,
            parentNamehash,
            label,
            registrationLength
        );

        assertEq(renewalPrice, 1 ether, "renewal price should be $1");
    }

    function testSetup100PercentReductionForAddressRegistrationAndRenewalShouldBeMinPrice_pass(
        uint256 _minPrice
    ) public {
        _minPrice = bound(_minPrice, 0, 1000000);

        string memory label = "foo";
        uint256 registrationLength = 365;
        bytes32 parentNamehash = Namehash.getTldNamehash("yoyo");

        uint256 annualCost = 2000 ether; //should be $4000 total

        tld.register(address(this), "yoyo");

        ISldRegistrationStrategy strategy = new MockRegistrationStrategy(annualCost);

        sld.setMockRegistrationStrategy(parentNamehash, strategy);
        tld.addRegistrationStrategy(parentNamehash, strategy);

        setUpLabelValidator();
        setUpGlobalStrategy(true, _minPrice * 1 ether);
        addMockOracle();

        address addr = address(0x225599);
        uint256 discount = 100;

        address[] memory arr1 = new address[](1);
        SldDiscountSettings[] memory arr2 = new SldDiscountSettings[](1);

        arr1[0] = addr;

        // uint80 startTimestamp;
        // uint80 endTimestamp;
        // uint8 discountPercentage;
        // bool isRegistration;
        // bool isRenewal;

        arr2[0] = SldDiscountSettings(0, type(uint80).max, 100, true, true);

        manager.setAddressDiscounts(parentNamehash, arr1, arr2);

        uint256 price = manager.getRegistrationPrice(
            strategy,
            addr,
            parentNamehash,
            label,
            registrationLength
        );

        hoax(addr, price);
        manager.registerSld{value: price}(
            label,
            bytes32(uint256(555)),
            registrationLength,
            parentNamehash,
            addr
        );

        uint256 expected = _minPrice * 1 ether;
        assertEq(price, expected, "price should be min price");

        uint256 renewalPrice = manager.getRenewalPrice(
            addr,
            parentNamehash,
            label,
            registrationLength
        );

        assertEq(renewalPrice, expected, "renewal price should min price");
    }

    function testSetup100PercentReductionForAddressRegistrationAndRenewalShouldBeMinPriceUpdateGlobalRules_pass()
        public
    {
        uint256 minPrice = 10;

        string memory label = "foo";
        uint256 registrationLength = 365;
        bytes32 parentNamehash = Namehash.getTldNamehash("yoyo");

        uint256 annualCost = 2000 ether; //should be $4000 total

        tld.register(address(this), "yoyo");

        ISldRegistrationStrategy strategy = new MockRegistrationStrategy(annualCost);

        sld.setMockRegistrationStrategy(parentNamehash, strategy);
        tld.addRegistrationStrategy(parentNamehash, strategy);

        setUpLabelValidator();
        setUpGlobalStrategy(true, minPrice * 1 ether);
        addMockOracle();

        address addr = address(0x225599);
        uint256 discount = 100;

        address[] memory arr1 = new address[](1);
        SldDiscountSettings[] memory arr2 = new SldDiscountSettings[](1);

        arr1[0] = addr;

        // uint80 startTimestamp;
        // uint80 endTimestamp;
        // uint8 discountPercentage;
        // bool isRegistration;
        // bool isRenewal;

        arr2[0] = SldDiscountSettings(0, type(uint80).max, 100, true, true);

        manager.setAddressDiscounts(parentNamehash, arr1, arr2);

        uint256 price = manager.getRegistrationPrice(
            strategy,
            addr,
            parentNamehash,
            label,
            registrationLength
        );

        hoax(addr, price);
        manager.registerSld{value: price}(
            label,
            bytes32(uint256(555)),
            registrationLength,
            parentNamehash,
            addr
        );

        assertEq(price, minPrice * 1 ether, "price should be min price");

        uint256 renewalPrice = manager.getRenewalPrice(
            addr,
            parentNamehash,
            label,
            registrationLength
        );

        assertEq(renewalPrice, minPrice * 1 ether, "renewal price should min price");

        minPrice = 55 ether;

        setUpGlobalStrategy(true, minPrice * 1 ether);

        label = "bar";

        price = manager.getRegistrationPrice(
            strategy,
            addr,
            parentNamehash,
            label,
            registrationLength
        );

        hoax(addr, price);
        manager.registerSld{value: price}(
            label,
            bytes32(uint256(555)),
            registrationLength,
            parentNamehash,
            addr
        );

        assertEq(price, minPrice * 1 ether, "price should be min price");

        renewalPrice = manager.getRenewalPrice(addr, parentNamehash, label, registrationLength);

        assertEq(renewalPrice, minPrice * 1 ether, "renewal price should min price");
    }

    //
}

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

contract TestSldRegistrationManagerRenewSldTests is TestSldRegistrationManagerBase {
    function setUp() public override {
        vm.warp(365 days);
        super.setUp();
    }

    function testRenewSldFromSldOwner_pass() public {
        ILabelValidator validator = new MockLabelValidator(true);
        manager.updateLabelValidator(validator);
        setUpGlobalStrategy(true, true, 1 ether);

        bytes32 parentNamehash = bytes32(uint256(0x4));
        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);

        string memory label = "yo";
        bytes32 secret = 0x0;
        uint80 registrationLength = 500;
        uint80 renewalLength = 1200;

        address recipient = address(0x5555);

        startHoax(address(0x420), 50 ether);

        manager.registerWithCommit{value: 2 ether}(
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

    function testRenewSldFromSldOwnerExpiredTld_pass() public {
        ILabelValidator validator = new MockLabelValidator(true);
        manager.updateLabelValidator(validator);
        setUpGlobalStrategy(true, true, 1 ether);

        bytes32 parentNamehash = bytes32(uint256(0x4));
        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);

        string memory label = "yo";
        bytes32 secret = 0x0;
        uint80 registrationLength = 500;
        uint80 renewalLength = 1200;

        uint256 regdate = block.timestamp;

        address recipient = address(0x5555);

        startHoax(address(0x420), 50 ether);

        manager.registerWithCommit{value: 2 ether}(
            label,
            secret,
            registrationLength,
            parentNamehash,
            recipient
        );

        vm.warp(tld.expiry(parentNamehash) + 100);
        manager.renewSld{value: 5 ether}(label, parentNamehash, renewalLength);

        (
            uint80 actualRegistrationTime,
            uint80 actualRegistrationLength, // uint96 actualRegistrationPrice

        ) = manager.sldRegistrationHistory(Namehash.getNamehash(parentNamehash, label));

        uint256 expectedValue = actualRegistrationTime + actualRegistrationLength;
        uint256 actualValue = regdate + ((registrationLength + renewalLength) * 1 days);

        //check that the registration details have been updated.
        assertEq(actualValue, expectedValue, "invalid registration details");
    }

    function testRenewSldFromSldOwnerGlobalRulesFail_fail() public {
        ILabelValidator validator = new MockLabelValidator(true);
        manager.updateLabelValidator(validator);
        setUpGlobalStrategy(true, false, 1 ether);

        bytes32 parentNamehash = bytes32(uint256(0x4));
        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);

        string memory label = "yo";
        bytes32 secret = 0x0;
        uint80 registrationLength = 500;
        uint80 renewalLength = 1200;

        address recipient = address(0x5555);

        startHoax(address(0x420), 50 ether);

        manager.registerWithCommit{value: 2 ether}(
            label,
            secret,
            registrationLength,
            parentNamehash,
            recipient
        );

        vm.expectRevert("cannot renew");
        manager.renewSld{value: 5 ether}(label, parentNamehash, renewalLength);
    }

    function testRenewSldFromNotSldOwner_pass() public {
        ILabelValidator validator = new MockLabelValidator(true);
        manager.updateLabelValidator(validator);
        setUpGlobalStrategy(true, true, 1 ether);

        bytes32 parentNamehash = bytes32(uint256(0x4));
        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);

        string memory label = "yo";
        bytes32 secret = 0x0;
        uint80 registrationLength = 500;
        uint80 renewalLength = 1200;

        address recipient = address(0x5555);

        startHoax(address(0x420), 30 ether);

        manager.registerWithCommit{value: 2 ether}(
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
        setUpGlobalStrategy(true, true, 1 ether);

        bytes32 parentNamehash = bytes32(uint256(0x4));
        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);

        string memory label = "yo";
        bytes32 secret = 0x0;
        uint80 registrationLength = 500;
        uint80 renewalLength = 1200;

        address recipient = address(0x5555);

        startHoax(address(0x420), 20 ether);
        manager.registerWithCommit{value: 2 ether}(
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
        setUpGlobalStrategy(true, true, 1 ether);

        bytes32 parentNamehash = bytes32(uint256(0x4));
        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);

        string memory label = "yo";
        bytes32 secret = 0x0;
        uint80 registrationLength = 500;

        address recipient = address(0x5555);

        hoax(address(0x420), 20 ether);
        manager.registerWithCommit{value: 2 ether}(
            label,
            secret,
            registrationLength,
            parentNamehash,
            recipient
        );

        vm.warp(block.timestamp + (registrationLength * 86400) + 1 + 30 days);

        vm.prank(address(0x420));
        vm.expectRevert("invalid domain");
        manager.renewSld(label, parentNamehash, registrationLength);
    }

    function testRenewExpiredSldInGracePeriod() public {
        ILabelValidator validator = new MockLabelValidator(true);
        manager.updateLabelValidator(validator);
        setUpGlobalStrategy(true, true, 1 ether);

        bytes32 parentNamehash = bytes32(uint256(0x4));
        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);

        string memory label = "yo";
        bytes32 secret = 0x0;
        uint80 registrationLength = 500;

        address recipient = address(0x5555);

        hoax(address(0x420), 20 ether);
        manager.registerWithCommit{value: 2 ether}(
            label,
            secret,
            registrationLength,
            parentNamehash,
            recipient
        );

        vm.warp(block.timestamp + (registrationLength * 86400) - 1 + 30 days);

        vm.prank(address(0x420));
        manager.renewSld{value: 3 ether}(label, parentNamehash, registrationLength);
    }

    function testRegisterExpiredSldInGracePeriod() public {
        ILabelValidator validator = new MockLabelValidator(true);
        manager.updateLabelValidator(validator);
        setUpGlobalStrategy(true, true, 1 ether);

        bytes32 parentNamehash = bytes32(uint256(0x4));
        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);

        string memory label = "yo";
        bytes32 secret = 0x0;
        uint80 registrationLength = 500;

        address recipient = address(0x5555);

        hoax(address(0x420), 20 ether);
        manager.registerWithCommit{value: 2 ether}(
            label,
            secret,
            registrationLength,
            parentNamehash,
            recipient
        );

        vm.warp(block.timestamp + (registrationLength * 86400) - 1 + 30 days);

        hoax(address(0x420), 20 ether);
        vm.expectRevert("domain already registered");
        manager.registerWithCommit{value: 2 ether}(
            label,
            secret,
            registrationLength,
            parentNamehash,
            recipient
        );
    }

    function testRenewDomainLessThan365Days() public {
        ILabelValidator validator = new MockLabelValidator(true);
        manager.updateLabelValidator(validator);
        setUpGlobalStrategy(true, true, 1 ether);

        bytes32 parentNamehash = bytes32(uint256(0x4));
        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);

        string memory label = "yo";
        bytes32 secret = 0x0;
        uint80 registrationLength = 364;

        address recipient = address(0x5555);

        hoax(address(0x420), 20 ether);
        manager.registerWithCommit{value: 2 ether}(
            label,
            secret,
            registrationLength,
            parentNamehash,
            recipient
        );

        manager.renewSld{value: 1 ether}(label, parentNamehash, registrationLength);
    }

    function testRenewSldCheaperPriceInUpdatedRegistrationRules_useCheaperPrice(
        uint8 _years
    ) public {
        _years = uint8(bound(_years, 1, 25));

        setUpLabelValidator();
        setUpGlobalStrategy(true, true, 1 ether);

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

        manager.registerWithCommit{value: 10 ether + 1}("yo", 0x0, 365, parentNamehash, address(0));

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
        setUpGlobalStrategy(true, true, 1 ether);

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
        manager.registerWithCommit{value: 10.11 ether}(
            label,
            secret,
            registrationLength,
            parentNamehash,
            recipient
        );

        // funds should be returned to msg.sender
        assertEq(sendingAddress.balance, 0.11 ether, "balance not correct");

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

    function testSetup100PercentReductionWithRevertingPriceStrategy_pass() public {
        string memory label = "foo";
        uint256 registrationLength = 365;
        bytes32 parentNamehash = Namehash.getTldNamehash("yoyo");

        uint256 annualCost = 2000 ether; //should be $4000 total

        tld.register(address(this), "yoyo");

        ISldRegistrationStrategy strategy = new MockRegistrationStrategy(annualCost);

        sld.setMockRegistrationStrategy(parentNamehash, strategy);

        setUpLabelValidator();
        setUpGlobalStrategy(true, true, 1 ether);
        addMockOracle();

        address addr = address(0x225599);

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
            address(strategy),
            addr,
            parentNamehash,
            label,
            registrationLength
        );

        hoax(addr, price);
        manager.registerWithCommit{value: price}(
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
        setUpGlobalStrategy(true, true, 1 ether);
        addMockOracle();

        address addr = address(0x225599);

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
            address(strategy),
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
        setUpGlobalStrategy(true, true, 1 ether);
        addMockOracle();

        address addr = address(0x225599);

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
            address(strategy),
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
        setUpGlobalStrategy(true, true, 1 ether);
        addMockOracle();

        address addr = address(0x225599);

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
            address(strategy2),
            addr,
            parentNamehash,
            label,
            registrationLength
        );

        assertEq(price, annualCost, "price should be $2000");

        hoax(addr, price);
        manager.registerWithCommit{value: price}(
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
        setUpGlobalStrategy(true, true, minPrice * 1 ether);
        addMockOracle();

        address addr = address(0x225599);

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
            address(strategy),
            addr,
            parentNamehash,
            label,
            registrationLength
        );

        hoax(addr, price);
        manager.registerWithCommit{value: price}(
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

        setUpGlobalStrategy(true, true, minPrice * 1 ether);

        label = "bar";

        price = manager.getRegistrationPrice(
            address(strategy),
            addr,
            parentNamehash,
            label,
            registrationLength
        );

        hoax(addr, price);
        manager.registerWithCommit{value: price}(
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
}

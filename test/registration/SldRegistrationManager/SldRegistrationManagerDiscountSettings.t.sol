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

contract TestSldRegistrationManagerContractOwnerTests is TestSldRegistrationManagerBase {
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
            address(strategy2),
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
            address(strategy2),
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
            address(strategy2),
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
            address(strategy2),
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
            address(strategy),
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
            address(strategy),
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
            address(strategy),
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
            address(strategy),
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

        assertEq(price, 1 ether, "registration should be at minimum cost");

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
            address(strategy),
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
            address(strategy),
            addr,
            parentNamehash,
            label,
            registrationLength
        );

        assertEq(price, annualCost, "registration should be at full cost"); //not started yet

        vm.warp(start + 20);

        price = manager.getRegistrationPrice(
            address(strategy),
            addr,
            parentNamehash,
            label,
            registrationLength
        );

        assertEq(price, annualCost / 2, "registration should be 50% cost"); //started now

        vm.warp(start + 40);

        price = manager.getRegistrationPrice(
            address(strategy),
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

        address owner = address(0x2);

        tld.register(owner, "yoyo");

        ISldRegistrationStrategy strategy = new MockRegistrationStrategy(annualCost);

        sld.setMockRegistrationStrategy(parentNamehash, strategy);
        tld.addRegistrationStrategy(parentNamehash, strategy);

        setUpLabelValidator();
        setUpGlobalStrategy(true, 1 ether);
        addMockOracle();

        vm.startPrank(owner);

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
            address(strategy),
            arr1[0],
            parentNamehash,
            label,
            registrationLength
        );

        assertEq(price, 100 ether, "registration should be full price");

        vm.stopPrank();
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
            address(strategy),
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
}

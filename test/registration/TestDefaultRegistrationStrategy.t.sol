// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import {Namehash} from "utils/Namehash.sol";

import "contracts/DefaultRegistrationStrategy.sol";
import "test/mocks/MockHandshakeTld.sol";
import "test/mocks/MockGlobalRegistrationStrategy.sol";
import "test/mocks/MockSldRegistrationManager.sol";

contract TestDefaultRegistrationStrategy is Test {
    using stdStorage for StdStorage;

    DefaultRegistrationStrategy strategy;
    MockHandshakeTld tld;

    function setUp() public {
        tld = new MockHandshakeTld();

        MockGlobalRegistrationStrategy globalStrategy = new MockGlobalRegistrationStrategy(true, true, 1 ether);

        MockSldRegistrationManager sldRegistrationManager = new MockSldRegistrationManager(tld, globalStrategy);
        strategy = new DefaultRegistrationStrategy(sldRegistrationManager);
    }

    function testSetLengthPrices_pass() public {
        bytes32 namehash = bytes32(uint256(0x1234));
        tld.addMapping(uint256(namehash), address(this), true);
        tld.register(address(this), uint256(namehash));

        uint256[] memory prices = new uint256[](4);

        prices[0] = 15;
        prices[1] = 10;
        prices[2] = 10;
        prices[3] = 5;

        strategy.setLengthCost(namehash, prices);

        for (uint256 i; i < prices.length; i++) {
            assertEq(strategy.lengthCost(namehash, i), prices[i]);
        }
    }

    function testSetLengthPricesInvalidSequence_fail() public {
        bytes32 namehash = bytes32(uint256(0x1234));
        tld.addMapping(uint256(namehash), address(this), true);
        tld.register(address(this), uint256(namehash));
        uint256[] memory prices = new uint256[](3);

        prices[0] = 15;
        prices[1] = 10;
        prices[2] = 11;

        vm.expectRevert("must be less than or equal to previous length");
        strategy.setLengthCost(namehash, prices);
    }

    function testSetLengthPricesWithMoreThanTenCharacters_fail() public {
        bytes32 namehash = bytes32(uint256(0x1234));
        tld.addMapping(uint256(namehash), address(this), true);
        tld.register(address(this), uint256(namehash));

        uint256[] memory prices = new uint256[](11);

        prices[0] = 11;
        prices[1] = 10;
        prices[2] = 9;
        prices[3] = 8;
        prices[4] = 7;
        prices[5] = 6;
        prices[6] = 5;
        prices[7] = 4;
        prices[8] = 3;
        prices[9] = 2;
        prices[10] = 1;

        vm.expectRevert("max 10 characters");
        strategy.setLengthCost(namehash, prices);
    }

    function testSetLengthPricesFromNotApprovedWallet_fail() public {
        bytes32 namehash = bytes32(uint256(0x1234));
        tld.addMapping(uint256(namehash), address(this), true);
        tld.register(address(this), uint256(namehash));
        uint256[] memory prices = new uint256[](3);

        prices[0] = 15;
        prices[1] = 10;
        prices[2] = 5;

        vm.prank(address(0x5555));
        vm.expectRevert("not approved or owner");
        strategy.setLengthCost(namehash, prices);
    }

    function testSetPremiumName_pass() public {
        uint256 price = 456;
        string memory label = "label";
        bytes32 namehash = bytes32(uint256(0x1234));
        tld.register(address(this), uint256(namehash));
        tld.addMapping(uint256(namehash), address(this), true);

        string[] memory labels = new string[](1);
        uint256[] memory prices = new uint256[](1);

        labels[0] = label;
        prices[0] = price;

        strategy.setPremiumNames(namehash, labels, prices);

        bytes32 full_hash = Namehash.getNamehash(namehash, label);

        assertEq(strategy.premiumNames(full_hash), price);
    }

    function testSetPremiumNameFromNotApprovedAddress_fail() public {
        uint256 price = 456;
        string memory label = "label";
        bytes32 namehash = bytes32(uint256(0x1234));
        tld.register(address(this), uint256(namehash));
        tld.addMapping(uint256(namehash), address(this), true);

        string[] memory labels = new string[](1);
        uint256[] memory prices = new uint256[](1);

        labels[0] = label;
        prices[0] = price;

        vm.prank(address(0x6666));
        vm.expectRevert("not approved or owner");
        strategy.setPremiumNames(namehash, labels, prices);

        bytes32 full_hash = keccak256(abi.encodePacked(keccak256(abi.encodePacked(label)), namehash));

        assertEq(strategy.premiumNames(full_hash), 0);
    }

    function testSetReservedNameFromNotApprovedAddress_fail() public {
        address claimer = address(0x77899);
        string memory label = "label";
        bytes32 namehash = bytes32(uint256(0x1234));
        tld.register(address(this), uint256(namehash));
        tld.addMapping(uint256(namehash), address(this), true);

        string[] memory labels = new string[](1);
        address[] memory claimers = new address[](1);

        labels[0] = label;
        claimers[0] = claimer;

        vm.prank(address(0x6666));
        vm.expectRevert("not approved or owner");
        strategy.setReservedNames(namehash, labels, claimers);

        bytes32 full_hash = keccak256(abi.encodePacked(keccak256(abi.encodePacked(label)), namehash));

        assertEq(strategy.reservedNames(full_hash), address(0));
    }

    function testSetMultiplePremiumNameAndClaim_pass() public {
        uint256 price = 456;
        uint256 price2 = 666;
        uint256 price3 = 9999;

        string memory label = "label";
        string memory label2 = "label2";
        string memory label3 = "label3";

        bytes32 namehash = bytes32(uint256(0x1234));
        tld.register(address(this), uint256(namehash));
        tld.addMapping(uint256(namehash), address(this), true);

        string[] memory labels = new string[](3);
        uint256[] memory prices = new uint256[](3);

        labels[0] = label;
        labels[1] = label2;
        labels[2] = label3;

        prices[0] = price;
        prices[1] = price2;
        prices[2] = price3;

        strategy.setPremiumNames(namehash, labels, prices);

        bytes32 full_hash = Namehash.getNamehash(namehash, label);
        bytes32 full_hash2 = Namehash.getNamehash(namehash, label2);
        bytes32 full_hash3 = Namehash.getNamehash(namehash, label3);

        assertEq(strategy.premiumNames(full_hash), price);
        assertEq(strategy.premiumNames(full_hash2), price2);
        assertEq(strategy.premiumNames(full_hash3), price3);
    }

    function testSetReservedNameAndClaim_pass() public {
        address claimer = address(0x77899);
        string memory label = "label";
        bytes32 namehash = bytes32(uint256(0x1234));
        tld.register(address(this), uint256(namehash));
        tld.addMapping(uint256(namehash), address(this), true);

        string[] memory labels = new string[](1);
        address[] memory claimers = new address[](1);

        labels[0] = label;
        claimers[0] = claimer;

        strategy.setReservedNames(namehash, labels, claimers);

        bytes32 full_hash = Namehash.getNamehash(namehash, label);
        assertEq(strategy.reservedNames(full_hash), claimer);
    }

    function testSetReservedNameAndClaimFromOtherWallet_fail() public {
        address claimer = address(0x77899);
        string memory label = "label";
        bytes32 namehash = bytes32(uint256(0x1234));
        tld.register(address(this), uint256(namehash));
        tld.addMapping(uint256(namehash), address(this), true);

        string[] memory labels = new string[](1);
        address[] memory claimers = new address[](1);

        labels[0] = label;
        claimers[0] = claimer;

        strategy.setReservedNames(namehash, labels, claimers);

        vm.expectRevert("reserved name");
        strategy.getPriceInDollars(address(0x420), namehash, label, 365, false);
    }

    function testSetReservedNameAndRenewFromOtherWallet_pass() public {
        address claimer = address(0x77899);
        string memory label = "label";
        bytes32 namehash = bytes32(uint256(0x1234));
        tld.register(address(this), uint256(namehash));
        tld.addMapping(uint256(namehash), address(this), true);

        string[] memory labels = new string[](1);
        address[] memory claimers = new address[](1);
        uint256[] memory prices = new uint256[](1);

        uint256 priceInDollarsPerYear = 5;

        labels[0] = label;
        claimers[0] = claimer;
        prices[0] = priceInDollarsPerYear;

        strategy.setReservedNames(namehash, labels, claimers);
        strategy.setPremiumNames(namehash, labels, prices);

        uint256 price = strategy.getPriceInDollars(address(0x420), namehash, label, 365, true);
        assertEq(price, 5 ether);
    }

    function testRegisterReservedSldTransferRenewWithBasePrice() public {
        address claimer = address(0x77899);
        string memory label = "label";
        bytes32 namehash = bytes32(uint256(0x1234));
        tld.register(address(this), uint256(namehash));
        tld.addMapping(uint256(namehash), address(this), true);

        string[] memory labels = new string[](1);
        address[] memory claimers = new address[](1);
        uint256[] memory prices = new uint256[](1);

        uint256 priceInDollarsPerYear = 5;

        labels[0] = label;
        claimers[0] = claimer;
        prices[0] = priceInDollarsPerYear;

        strategy.setReservedNames(namehash, labels, claimers);
        strategy.setPremiumNames(namehash, labels, prices);

        uint256 price = strategy.getPriceInDollars(address(0x420), namehash, label, 365, true);
        assertEq(price, 5 ether);
    }

    function testSetMultipleReservedNamesAndClaim_pass() public {
        address claimer = address(0x77899);
        address claimer2 = address(0x998877);
        address claimer3 = address(0x775533);

        string memory label = "label";
        string memory label2 = "label2";
        string memory label3 = "label3";
        bytes32 namehash = bytes32(uint256(0x1234));
        tld.register(address(this), uint256(namehash));
        tld.addMapping(uint256(namehash), address(this), true);

        string[] memory labels = new string[](3);
        address[] memory claimers = new address[](3);

        labels[0] = label;
        labels[1] = label2;
        labels[2] = label3;

        claimers[0] = claimer;
        claimers[1] = claimer2;
        claimers[2] = claimer3;

        strategy.setReservedNames(namehash, labels, claimers);

        bytes32 full_hash = Namehash.getNamehash(namehash, label);
        bytes32 full_hash2 = Namehash.getNamehash(namehash, label2);
        bytes32 full_hash3 = Namehash.getNamehash(namehash, label3);

        assertEq(strategy.reservedNames(full_hash), claimer);
        assertEq(strategy.reservedNames(full_hash2), claimer2);
        assertEq(strategy.reservedNames(full_hash3), claimer3);
    }

    function testSetMultipleReservedNamesNotMatchingArrays_fail() public {
        address claimer = address(0x77899);
        address claimer2 = address(0x998877);
        address claimer3 = address(0x775533);

        string memory label = "label";
        string memory label2 = "label2";

        bytes32 namehash = bytes32(uint256(0x1234));
        tld.register(address(this), uint256(namehash));
        tld.addMapping(uint256(namehash), address(this), true);

        string[] memory labels = new string[](2);
        address[] memory claimers = new address[](3);

        labels[0] = label;
        labels[1] = label2;

        claimers[0] = claimer;
        claimers[1] = claimer2;
        claimers[2] = claimer3;

        vm.expectRevert("array lengths do not match");
        strategy.setReservedNames(namehash, labels, claimers);
    }

    function testSetMultiplePremiumNameNotMatchingArrays_fail() public {
        uint256 price = 456;
        uint256 price2 = 666;

        string memory label = "label";
        string memory label2 = "label2";
        string memory label3 = "label3";

        bytes32 namehash = bytes32(uint256(0x1234));
        tld.register(address(this), uint256(namehash));
        tld.addMapping(uint256(namehash), address(this), true);

        string[] memory labels = new string[](3);
        uint256[] memory prices = new uint256[](2);

        labels[0] = label;
        labels[1] = label2;
        labels[2] = label3;

        prices[0] = price;
        prices[1] = price2;

        vm.expectRevert("array lengths do not match");
        strategy.setPremiumNames(namehash, labels, prices);
    }

    function testGetPriceInDollarsFromPremiumName_pass() public {
        bytes32 namehash = bytes32(uint256(0x5464654));
        string memory label = "label";
        tld.register(address(0x1234), uint256(namehash));
        bytes32 full_namehash = Namehash.getNamehash(namehash, label);
        uint256 price = 50;
        stdstore.target(address(strategy)).sig("premiumNames(bytes32)").with_key(full_namehash).checked_write(price);

        uint256 actualPrice = strategy.getPriceInDollars(address(this), namehash, label, 365, false);
        assertEq(actualPrice, 50 ether);

        //it should round this one up to the next dollar
        actualPrice = strategy.getPriceInDollars(address(this), namehash, label, 366, false);
        assertEq(actualPrice, 50136986301369863013);

        //it should round this one another dollar
        actualPrice = strategy.getPriceInDollars(address(this), namehash, label, 373, false);
        assertEq(actualPrice, 51095890410958904109);

        //should be $500 for 10 years
        actualPrice = strategy.getPriceInDollars(address(this), namehash, label, 3650, false);
        assertEq(actualPrice, 500 ether);
    }

    function testGetPriceInDollarsFromReservedName_pass() public {
        bytes32 namehash = bytes32(uint256(0x5464654));
        string memory label = "label";
        bytes32 full_namehash = Namehash.getNamehash(namehash, label);
        address addr = address(0x335577);
        stdstore.target(address(strategy)).sig("reservedNames(bytes32)").with_key(full_namehash).checked_write(addr);

        uint256[] memory prices = new uint256[](1);
        prices[0] = 10;

        tld.register(address(this), uint256(namehash));
        tld.addMapping(uint256(namehash), address(this), true);

        strategy.setLengthCost(namehash, prices);

        console.log("length cost", strategy.getPriceInDollars(addr, namehash, label, 365, false));
        uint256 actualPrice = strategy.getPriceInDollars(addr, namehash, label, 365, false);
        assertEq(actualPrice, 10 ether);

        //it should round this one up to the next dollar
        actualPrice = strategy.getPriceInDollars(addr, namehash, label, 366, false);
        assertEq(actualPrice, 10027397260273972602);

        //it should round this one another dollar
        actualPrice = strategy.getPriceInDollars(addr, namehash, label, 373, false);
        assertEq(actualPrice, 10219178082191780821);

        actualPrice = strategy.getPriceInDollars(addr, namehash, label, 365 * 2, false);
        assertEq(actualPrice, 20 ether);

        //should be $500 for 10 years
        actualPrice = strategy.getPriceInDollars(addr, namehash, label, 3650, false);
        assertEq(actualPrice, 100 ether);
    }

    function testGetPriceInDollarsWithDifferentLengths_pass() public {
        bytes32 namehash = bytes32(uint256(0x5464654));

        uint256[] memory arr = new uint256[](5);

        arr[0] = 29;
        arr[1] = 28;
        arr[2] = 27;
        arr[3] = 26;
        arr[4] = 25;

        tld.addMapping(uint256(namehash), address(this), true);
        tld.register(address(this), uint256(namehash));

        strategy.setLengthCost(namehash, arr);

        uint256 actualPrice = strategy.getPriceInDollars(address(0x1337), namehash, "1", 365, false);
        assertEq(actualPrice, 29 ether);

        actualPrice = strategy.getPriceInDollars(address(0x1337), namehash, "12", 365, false);
        assertEq(actualPrice, 28 ether);

        actualPrice = strategy.getPriceInDollars(address(0x1337), namehash, "123", 365, false);
        assertEq(actualPrice, 27 ether);

        actualPrice = strategy.getPriceInDollars(address(0x1337), namehash, "1234", 365, false);
        assertEq(actualPrice, 26 ether);

        actualPrice = strategy.getPriceInDollars(address(0x1337), namehash, "12345", 365, false);
        assertEq(actualPrice, 25 ether);

        //these should be $25 as they are past the max number
        actualPrice = strategy.getPriceInDollars(address(0x1337), namehash, "123456", 365, false);
        assertEq(actualPrice, 25 ether);

        actualPrice = strategy.getPriceInDollars(address(0x1337), namehash, "123457", 365, false);
        assertEq(actualPrice, 25 ether);

        actualPrice = strategy.getPriceInDollars(
            address(0x1337), namehash, "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", 365, false
        );
        assertEq(actualPrice, 25 ether);
    }

    function testGetPriceInDollarsWithDifferentLengthsMultipleYears_pass() public {
        bytes32 namehash = bytes32(uint256(0x5464654));

        uint256[] memory arr = new uint256[](5);

        arr[0] = 29;
        arr[1] = 28;
        arr[2] = 27;
        arr[3] = 26;
        arr[4] = 25;

        tld.addMapping(uint256(namehash), address(this), true);
        tld.register(address(this), uint256(namehash));

        strategy.setLengthCost(namehash, arr);

        uint256 actualPrice = strategy.getPriceInDollars(address(0x1337), namehash, "1", 365 * 2, false);
        assertEq(actualPrice, 29 ether * 2);

        actualPrice = strategy.getPriceInDollars(address(0x1337), namehash, "12", 365 * 2, false);
        assertEq(actualPrice, 28 ether * 2);

        actualPrice = strategy.getPriceInDollars(address(0x1337), namehash, "123", 365 * 2, false);
        assertEq(actualPrice, 27 ether * 2);

        actualPrice = strategy.getPriceInDollars(address(0x1337), namehash, "1234", 365 * 2, false);
        assertEq(actualPrice, 26 ether * 2);

        actualPrice = strategy.getPriceInDollars(address(0x1337), namehash, "12345", 365 * 2, false);
        assertEq(actualPrice, 25 ether * 2);

        //these should be $25 as they are past the max number
        actualPrice = strategy.getPriceInDollars(address(0x1337), namehash, "123456", 365 * 2, false);
        assertEq(actualPrice, 25 ether * 2);

        actualPrice = strategy.getPriceInDollars(address(0x1337), namehash, "123457", 365 * 2, false);
        assertEq(actualPrice, 25 ether * 2);

        actualPrice = strategy.getPriceInDollars(
            address(0x1337), namehash, "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", 365 * 2, false
        );
        assertEq(actualPrice, 25 ether * 2);
    }

    function testMultiYearDiscountWithOver50Percent_fail() public {
        bytes32 namehash = bytes32(uint256(0x5464654));

        uint256[] memory multiYearDiscount = new uint256[](3);

        multiYearDiscount[0] = 0;
        multiYearDiscount[1] = 5;
        multiYearDiscount[2] = 51;

        tld.addMapping(uint256(namehash), address(this), true);
        tld.register(address(this), uint256(namehash));

        vm.expectRevert("max 50% discount");
        strategy.setMultiYearDiscount(namehash, multiYearDiscount);
    }

    function testMultiYearDiscountWithIncorrectDiscountSequence_fail() public {
        bytes32 namehash = bytes32(uint256(0x5464654));
        tld.register(address(this), uint256(namehash));
        uint256[] memory multiYearDiscount = new uint256[](3);

        multiYearDiscount[0] = 0;
        multiYearDiscount[1] = 50;
        multiYearDiscount[2] = 49;

        tld.addMapping(uint256(namehash), address(this), true);

        vm.expectRevert("must be more or equal to previous year");
        strategy.setMultiYearDiscount(namehash, multiYearDiscount);
    }

    function testGetPriceInDollarsWithMultiYearDiscount_pass() public {
        bytes32 namehash = bytes32(uint256(0x5464654));
        tld.register(address(this), uint256(namehash));
        uint256[] memory lengthPrices = new uint256[](1);

        lengthPrices[0] = 25;

        uint256[] memory multiYearDiscount = new uint256[](3);

        multiYearDiscount[0] = 0;
        multiYearDiscount[1] = 5;
        multiYearDiscount[2] = 10;

        tld.addMapping(uint256(namehash), address(this), true);

        strategy.setLengthCost(namehash, lengthPrices);
        strategy.setMultiYearDiscount(namehash, multiYearDiscount);

        uint256 actualPrice = strategy.getPriceInDollars(address(0x1337), namehash, "1", 365, false);
        assertEq(actualPrice, 25 ether);

        actualPrice = strategy.getPriceInDollars(address(0x1337), namehash, "1", 365 * 2, false);
        assertEq(actualPrice, (50 ether / 100) * 95);

        actualPrice = strategy.getPriceInDollars(address(0x1337), namehash, "1", 365 * 3, false);
        assertEq(actualPrice, (75 ether / 100) * 90);

        actualPrice = strategy.getPriceInDollars(address(0x1337), namehash, "1", 365 * 4, false);
        assertEq(actualPrice, (100 ether / 100) * 90);
    }

    function testGetPriceInDollarsWithMultiYearDiscountNotLessThanOneDollarPerYear_pass() public {
        bytes32 namehash = bytes32(uint256(0x5464654));
        uint256[] memory lengthPrices = new uint256[](1);

        lengthPrices[0] = 1;

        uint256[] memory multiYearDiscount = new uint256[](3);

        multiYearDiscount[0] = 0;
        multiYearDiscount[1] = 5;
        multiYearDiscount[2] = 10;

        tld.register(address(this), uint256(namehash));
        tld.addMapping(uint256(namehash), address(this), true);

        strategy.setLengthCost(namehash, lengthPrices);
        strategy.setMultiYearDiscount(namehash, multiYearDiscount);

        uint256 actualPrice = strategy.getPriceInDollars(address(0x1337), namehash, "1", 365, false);
        assertEq(actualPrice, 1 ether);

        actualPrice = strategy.getPriceInDollars(address(0x1337), namehash, "1", 365 * 2, false);
        assertEq(actualPrice, 2 ether);

        actualPrice = strategy.getPriceInDollars(address(0x1337), namehash, "1", 365 * 3, false);
        assertEq(actualPrice, 3 ether);

        actualPrice = strategy.getPriceInDollars(address(0x1337), namehash, "1", 365 * 4, false);
        assertEq(actualPrice, 4 ether);
    }

    function testGetPriceInDollarsWithMultiYearDiscountAndLengthPrices_pass() public {
        bytes32 namehash = bytes32(uint256(0x5464654));
        tld.register(address(this), uint256(namehash));
        uint256[] memory lengthPrices = new uint256[](3);

        lengthPrices[0] = 25;
        lengthPrices[1] = 15;
        lengthPrices[2] = 5;

        uint256[] memory multiYearDiscount = new uint256[](3);

        multiYearDiscount[0] = 0;
        multiYearDiscount[1] = 5;
        multiYearDiscount[2] = 10;

        tld.addMapping(uint256(namehash), address(this), true);

        strategy.setLengthCost(namehash, lengthPrices);
        strategy.setMultiYearDiscount(namehash, multiYearDiscount);

        uint256 actualPrice = strategy.getPriceInDollars(address(0x1337), namehash, "1", 365, false);
        assertEq(actualPrice, 25 ether);

        actualPrice = strategy.getPriceInDollars(address(0x1337), namehash, "1", 365 * 2, false);
        assertEq(actualPrice, (50 ether / 100) * 95);

        actualPrice = strategy.getPriceInDollars(address(0x1337), namehash, "1", 365 * 3, false);
        assertEq(actualPrice, (75 ether / 100) * 90);

        actualPrice = strategy.getPriceInDollars(address(0x1337), namehash, "1", 365 * 4, false);
        assertEq(actualPrice, (100 ether / 100) * 90);

        actualPrice = strategy.getPriceInDollars(address(0x1337), namehash, "12", 365, false);
        assertEq(actualPrice, 15 ether);

        actualPrice = strategy.getPriceInDollars(address(0x1337), namehash, "12", 365 * 2, false);
        assertEq(actualPrice, (30 ether / 100) * 95);

        actualPrice = strategy.getPriceInDollars(address(0x1337), namehash, "12", 365 * 3, false);
        assertEq(actualPrice, (45 ether / 100) * 90);

        actualPrice = strategy.getPriceInDollars(address(0x1337), namehash, "12", 365 * 4, false);
        assertEq(actualPrice, (60 ether / 100) * 90);

        actualPrice = strategy.getPriceInDollars(address(0x1337), namehash, "123", 365, false);
        assertEq(actualPrice, 5 ether);

        actualPrice = strategy.getPriceInDollars(address(0x1337), namehash, "123", 365 * 2, false);
        assertEq(actualPrice, (10 ether / 100) * 95);

        actualPrice = strategy.getPriceInDollars(address(0x1337), namehash, "123", 365 * 3, false);
        assertEq(actualPrice, (15 ether / 100) * 90);

        actualPrice = strategy.getPriceInDollars(address(0x1337), namehash, "123", 365 * 4, false);
        assertEq(actualPrice, (20 ether / 100) * 90);

        //should be the same as last costs due to only being max of 3 length in length prices
        actualPrice = strategy.getPriceInDollars(address(0x1337), namehash, "1234", 365, false);
        assertEq(actualPrice, 5 ether);

        actualPrice = strategy.getPriceInDollars(address(0x1337), namehash, "1234", 365 * 2, false);
        assertEq(actualPrice, (10 ether / 100) * 95);

        actualPrice = strategy.getPriceInDollars(address(0x1337), namehash, "1234", 365 * 3, false);
        assertEq(actualPrice, (15 ether / 100) * 90);

        actualPrice = strategy.getPriceInDollars(address(0x1337), namehash, "1234", 365 * 4, false);
        assertEq(actualPrice, (20 ether / 100) * 90);
    }

    function testSetisEnabledFromTokenOwner_pass() public {
        bytes32 namehash = bytes32(uint256(0x5464654));
        tld.register(address(this), uint256(namehash));

        assertFalse(strategy.isEnabled(namehash), "expect default false");

        strategy.setIsEnabled(namehash, true);

        assertTrue(strategy.isEnabled(namehash), "expect isEnabled() == true");
    }

    function testSetisEnabledFromApprovedAddress_pass() public {
        bytes32 namehash = bytes32(uint256(0x5464654));
        address approved = address(0x1337);
        tld.register(address(this), uint256(namehash));
        tld.setApprovalForAll(approved, true);

        vm.startPrank(approved);
        assertFalse(strategy.isEnabled(namehash), "expect default false");

        strategy.setIsEnabled(namehash, true);
        assertTrue(strategy.isEnabled(namehash), "expect isEnabled() == true");

        strategy.setIsEnabled(namehash, false);
        assertFalse(strategy.isEnabled(namehash), "expect isEnabled() == false");
    }

    function testSetisEnabledFromNotApprovedAddress_fail() public {
        bytes32 namehash = bytes32(uint256(0x5464654));
        address not_approved = address(0x1337);
        tld.register(address(this), uint256(namehash));

        vm.startPrank(not_approved);
        vm.expectRevert("not approved or owner");
        strategy.setIsEnabled(namehash, true);
    }
}

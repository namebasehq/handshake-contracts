// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

import "interfaces/ICommitIntent.sol";
import "contracts/GlobalRegistrationRules.sol";
import "interfaces/IGlobalRegistrationRules.sol";

contract GlobalRegistrationTests is Test {
    IGlobalRegistrationRules rules;

    function setUp() public {
        rules = new GlobalRegistrationRules();
    }

    function testClaimWithZeroDollars_fail() public {
        address buyingAddress = address(0x11);
        bytes32 parentNamehash = 0x0;
        string memory label = "testing";
        uint256 registrationLength = 365;
        uint256 dollarPrice = 0;
        bool result = rules.canRegister(
            buyingAddress,
            parentNamehash,
            label,
            registrationLength,
            dollarPrice
        );

        assertFalse(result, "should not be able to register with zero dollar");
    }

    function testClaimWithOneDollar_pass() public {
        address buyingAddress = address(0x11);
        bytes32 parentNamehash = 0x0;
        string memory label = "testing";
        uint256 registrationLength = 365;
        uint256 dollarPrice = 1;
        bool result = rules.canRegister(
            buyingAddress,
            parentNamehash,
            label,
            registrationLength,
            dollarPrice
        );

        assertTrue(result, "should be able to register with single dollar");
    }

    function testClaimWith365Days_pass() public {
        address buyingAddress = address(0x11);
        bytes32 parentNamehash = 0x0;
        string memory label = "testing";
        uint256 registrationLength = 365;
        uint256 dollarPrice = type(uint256).max;
        bool result = rules.canRegister(
            buyingAddress,
            parentNamehash,
            label,
            registrationLength,
            dollarPrice
        );

        assertTrue(result, "should be able to register with 365 days");
    }

    function testClaimWithLessThan365Days_fail() public {
        address buyingAddress = address(0x11);
        bytes32 parentNamehash = 0x0;
        string memory label = "testing";
        uint256 registrationLength = 364;
        uint256 dollarPrice = type(uint256).max;
        bool result = rules.canRegister(
            buyingAddress,
            parentNamehash,
            label,
            registrationLength,
            dollarPrice
        );

        assertFalse(result, "should not be able to register with less than 365 days");
    }

    function testClaimWithMultipleYearsBelowDollarAverage_fail() public {
        address buyingAddress = address(0x11);
        bytes32 parentNamehash = 0x0;
        string memory label = "testing";
        uint256 registrationLength = (365 * 100);
        uint256 dollarPrice = 99;
        bool result = rules.canRegister(
            buyingAddress,
            parentNamehash,
            label,
            registrationLength,
            dollarPrice
        );

        assertFalse(result, "should not be able to register with less $1 per year");
    }

    function testClaimWithMultipleYearsDollarAverage_pass() public {
        address buyingAddress = address(0x11);
        bytes32 parentNamehash = 0x0;
        string memory label = "testing";
        uint256 registrationLength = (365 * 100);
        uint256 dollarPrice = 100;
        bool result = rules.canRegister(
            buyingAddress,
            parentNamehash,
            label,
            registrationLength,
            dollarPrice
        );

        assertTrue(result, "should be able to register with $1 per year");
    }
}

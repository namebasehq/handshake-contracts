// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

import "interfaces/ICommitIntent.sol";
import "contracts/NameValidator.sol";

contract NameValidatorTests is Test {
    INameValidator validator;

    function setUp() public {
        validator = new NameValidator();
    }

    function testLowercaseLettersOnlyIsValid_pass() public {
        string memory name = "testing";
        bool valid = validator.isValidName(name);
        assertTrue(valid, "simple lowercase name is valid");
    }

    function testAlphanumericIsValid_pass() public {
        string memory name = "testing123";
        bool valid = validator.isValidName(name);
        assertTrue(valid, "alphanumeric name is valid");
    }

    function testUppercaseLettersIsInvalid_fail() public {
        string memory name = "TESTING";
        bool valid = validator.isValidName(name);
        assertFalse(valid, "uppercase name is invalid");
    }

    function testLowercaseLettersAndNumbersIsValid() public {}

    function testNumbersOnlyIsValid() public {}

    function testMaxSizeForDomain() public {}

    function testNullByteAtEndOfLabelFails() public {}

    function testNullByteAtStartOfLabelFails() public {}

    function testNullByteInMiddleOfLabelFails() public {}

    //find out what the min size of a domain is.. probably single char is acceptable.
    function testSingleLetterDomainLabel___provide_expected_behaviour() public {}

    function testSingleNumberDomainLabel___provide_expected_behaviour() public {}

    //find out what the max size of a label is. There needs to be a max size!!
    function testMaxSizePlusOneDomainFails() public {}
}

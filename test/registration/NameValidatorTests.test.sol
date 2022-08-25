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

    function testLowercaseLettersOnlyIsValid() public {
        string memory name = "testing";
        bool valid = validator.isValidName(name);
        assertTrue(valid, "simple lowercase name is valid");
    }

    function testLowercaseAlphanumericIsValid() public {
        string memory name = "testing123";
        bool valid = validator.isValidName(name);
        assertTrue(valid, "alphanumeric name is valid");
    }

    function testUppercaseLettersIsInvalid() public {
        string memory name = "TESTING";
        bool valid = validator.isValidName(name);
        assertFalse(valid, "uppercase name is invalid");
    }

    function testUppercaseAlphanumericIsInvalid() public {
        string memory name = "TESTING123";
        bool valid = validator.isValidName(name);
        assertFalse(valid, "uppercase alphanumeric name is invalid");
    }

    function testNumbersOnlyIsValid() public {
        string memory name = "123";
        bool valid = validator.isValidName(name);
        assertTrue(valid, "numbers only name is valid");
    }

    function testUnderscoreIsInvalid() public {
        string memory name = "test_ing";
        bool valid = validator.isValidName(name);
        assertFalse(valid, "underscore in name is invalid");
    }

    function testSpaceInMiddleOfLabelFails() public {
        string memory name = "test ing";
        bool valid = validator.isValidName(name);
        assertFalse(valid, "name with space is invalid");
    }

    function testSpaceAtStartOfLabelFails() public {
        string memory name = " testing";
        bool valid = validator.isValidName(name);
        assertFalse(valid, "name with leading space is invalid");
    }

    function testSpaceAtEndOfLabelFails() public {
        string memory name = "testing ";
        bool valid = validator.isValidName(name);
        assertFalse(valid, "name with trailing space is invalid");
    }

    function testNullByteLabelFails() public {
        bytes memory _bytes = "\u0000";
        string memory name = string(abi.encodePacked(_bytes));
        // console.log(name);
        // console.log(_bytes.length);
        bool valid = validator.isValidName(name);
        assertFalse(valid, "null byte is invalid");
    }

    function testNullByteInMiddleOfLabelFails() public {
        bytes memory _bytes = "tes\u0000ting";
        string memory name = string(abi.encodePacked(_bytes));
        bool valid = validator.isValidName(name);
        assertFalse(valid, "name with null byte is invalid");
    }

    function testNullByteAtStartOfLabelFails() public {
        bytes memory _bytes = "\u0000testing";
        string memory name = string(abi.encodePacked(_bytes));
        bool valid = validator.isValidName(name);
        assertFalse(valid, "name with leading null byte is invalid");
    }

    function testNullByteAtEndOfLabelFails() public {
        bytes memory _bytes = "testing\u0000";
        string memory name = string(abi.encodePacked(_bytes));
        bool valid = validator.isValidName(name);
        assertFalse(valid, "name with trailing null byte is invalid");
    }

    function testEmptyNameIsInvalid() public {
        string memory name = "";
        bool valid = validator.isValidName(name);
        assertFalse(valid, "empty name is invalid");
    }

    function testMinLengthIsValid() public {
        // 1 chars
        string memory name = "a";
        bool valid = validator.isValidName(name);
        assertTrue(valid, "name of minimum length is valid");
    }

    function testMaxLengthIsValid() public {
        // 63 chars
        string memory name = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
        bool valid = validator.isValidName(name);
        assertTrue(valid, "name of maximum length is valid");
    }

    function testOverMaxLengthIsInvalid() public {
        // 64 chars
        string memory name = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
        bool valid = validator.isValidName(name);
        assertFalse(valid, "name over maximum length is invalid");
    }
}

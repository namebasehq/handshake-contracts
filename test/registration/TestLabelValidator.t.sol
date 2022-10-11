// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

import "interfaces/ICommitIntent.sol";
import "contracts/LabelValidator.sol";

contract TestLabelValidator is Test {
    ILabelValidator validator;

    function setUp() public {
        validator = new LabelValidator();
    }

    function testLowercaseLettersOnlyPasses() public {
        string memory label = "testing";
        bool valid = validator.isValidLabel(label);
        assertTrue(valid, "simple lowercase is valid");
    }

    function testLowercaseAlphanumericPasses() public {
        string memory label = "testing123";
        bool valid = validator.isValidLabel(label);
        assertTrue(valid, "alphanumeric is valid");
    }

    function testNumbersOnlyPasses() public {
        string memory label = "123";
        bool valid = validator.isValidLabel(label);
        assertTrue(valid, "numbers only is valid");
    }

    function testUppercaseLettersFails() public {
        string memory label = "TESTING";
        bool valid = validator.isValidLabel(label);
        assertFalse(valid, "uppercase is invalid");
    }

    function testUppercaseAlphanumericFails() public {
        string memory label = "TESTING123";
        bool valid = validator.isValidLabel(label);
        assertFalse(valid, "uppercase alphanumeric is invalid");
    }

    function testPunycodeFails() public {
        string memory label = "xn--ls8h";
        bool valid = validator.isValidLabel(label);
        assertFalse(valid, "punycode is invalid");
    }

    function testEmptyPunycodeFails() public {
        string memory label = "xn--";
        bool valid = validator.isValidLabel(label);
        assertFalse(valid, "empty punycode is invalid");
    }

    function testInvalidDoubleHyphenFails() public {
        // double hyphens are allowed in DNS, but hyphens at position 3 & 4 indicates punycode
        string memory label = "aa--";
        bool valid = validator.isValidLabel(label);
        assertFalse(valid, "hyphens at position 3 & 4 is invalid");
    }

    function testDoubleHyphenFails() public {
        // double hyphens are allowed in DNS, but hyphens at position 3 & 4 indicates punycode
        string memory label = "aa--a";
        bool valid = validator.isValidLabel(label);
        assertFalse(valid, "hyphens at position 3 & 4 is invalid");
    }

    function testHyphenAloneFails() public {
        string memory label = "-";
        bool valid = validator.isValidLabel(label);
        assertFalse(valid, "hyphen alone is invalid");
    }

    function testHyphenInMiddleOfLabelPasses() public {
        string memory label = "test-ing";
        bool valid = validator.isValidLabel(label);
        assertTrue(valid, "hyphen in middle is valid");
    }

    function testHyphenAtStartOfLabelFails() public {
        string memory label = "-testing";
        bool valid = validator.isValidLabel(label);
        assertFalse(valid, "hyphen at start is invalid");
    }

    function testHyphenAtEndOfLabelFails() public {
        string memory label = "testing-";
        bool valid = validator.isValidLabel(label);
        assertFalse(valid, "hyphen at end is invalid");
    }

    function testUnderscoreAloneFails() public {
        string memory label = "_";
        bool valid = validator.isValidLabel(label);
        assertFalse(valid, "underscore alone is invalid");
    }

    function testUnderscoreInMiddleOfLabelFails() public {
        string memory label = "test_ing";
        bool valid = validator.isValidLabel(label);
        assertFalse(valid, "underscore in middle is invalid");
    }

    function testUnderscoreAtStartOfLabelFails() public {
        string memory label = "_testing";
        bool valid = validator.isValidLabel(label);
        assertFalse(valid, "underscore at start is invalid");
    }

    function testUnderscoreAtEndOfLabelFails() public {
        string memory label = "testing_";
        bool valid = validator.isValidLabel(label);
        assertFalse(valid, "underscore at end is invalid");
    }

    function testSpaceFails() public {
        string memory label = " ";
        bool valid = validator.isValidLabel(label);
        assertFalse(valid, "space is invalid");
    }

    function testSpaceInMiddleOfLabelFails() public {
        string memory label = "test ing";
        bool valid = validator.isValidLabel(label);
        assertFalse(valid, "space in middle is invalid");
    }

    function testSpaceAtStartOfLabelFails() public {
        string memory label = " testing";
        bool valid = validator.isValidLabel(label);
        assertFalse(valid, "space at start is invalid");
    }

    function testSpaceAtEndOfLabelFails() public {
        string memory label = "testing ";
        bool valid = validator.isValidLabel(label);
        assertFalse(valid, "space at end is invalid");
    }

    function testNullByteLabelFails() public {
        bytes memory _bytes = "\u0000";
        string memory label = string(abi.encodePacked(_bytes));
        bool valid = validator.isValidLabel(label);
        assertFalse(valid, "null byte is invalid");
    }

    function testNullByteInMiddleOfLabelFails() public {
        bytes memory _bytes = "tes\u0000ting";
        string memory label = string(abi.encodePacked(_bytes));
        bool valid = validator.isValidLabel(label);
        assertFalse(valid, "null byte in middle is invalid");
    }

    function testNullByteAtStartOfLabelFails() public {
        bytes memory _bytes = "\u0000testing";
        string memory label = string(abi.encodePacked(_bytes));
        bool valid = validator.isValidLabel(label);
        assertFalse(valid, "leading null byte is invalid");
    }

    function testNullByteAtEndOfLabelFails() public {
        bytes memory _bytes = "testing\u0000";
        string memory label = string(abi.encodePacked(_bytes));
        bool valid = validator.isValidLabel(label);
        assertFalse(valid, "trailing null byte is invalid");
    }

    function testEmptyLabelFails() public {
        string memory label = "";
        bool valid = validator.isValidLabel(label);
        assertFalse(valid, "empty label is invalid");
    }

    function testMinLengthIsValid() public {
        // 1 chars
        string memory label = "a";
        bool valid = validator.isValidLabel(label);
        assertTrue(valid, "label of minimum length is valid");
    }

    function testMaxLengthIsValid() public {
        // 63 chars
        string memory label = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
        bool valid = validator.isValidLabel(label);
        assertTrue(valid, "label of maximum length is valid");
    }

    function testOverMaxLengthFails() public {
        // 64 chars
        string memory label = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
        bool valid = validator.isValidLabel(label);
        assertFalse(valid, "label over maximum length is invalid");
    }
}

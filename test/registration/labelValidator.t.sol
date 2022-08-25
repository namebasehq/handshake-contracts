// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

import "interfaces/ICommitIntent.sol";
import "src/contracts/DomainLabelValidator.sol";

contract LabelValidatorTests is Test {
    function setUp() public {}

    function testLowercaseLettersOnlyIsValid() public {}

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

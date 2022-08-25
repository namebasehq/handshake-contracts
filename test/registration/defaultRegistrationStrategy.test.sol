// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

import "interfaces/IHandshakeSld.sol";
import "test/mocks/mockHandshakeSld.sol";
import "interfaces/ISldRegistrationStrategy.sol";
import "contracts/DefaultRegistrationStrategy.sol";

contract DefaultRegistrationStrategyTests is Test {

    IHandshakeSld SldContract;
    DefaultRegistrationStrategy DefaultStrategy;

    function setUp()public {
        SldContract = new MockHandshakeSld();
        DefaultStrategy = new DefaultRegistrationStrategy(SldContract);
    }

    function testSetFlatPrice() public {
        assertTrue(false, 'not implemented');
    }

    function testSetDiscountedPriceBasedOnYears() public {
        assertTrue(false, 'not implemented');
    }

    function testSetPriceBasedOnLength() public {
        assertTrue(false, 'not implemented');
    }

    function testPremiumWords() public {
        assertTrue(false, 'not implemented');
    }


}
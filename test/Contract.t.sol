// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

contract ContractTest is Test {
    function setUp() public {}

    function testExample(uint256 id) public {
        assertFalse(id > 100000);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

import "contracts/PublicResolver.sol";
import "test/resolvers/ResolverTests.t.sol";

contract PublicResolverTests is ResolverTests {

    function setUp() override public {
        resolver = new PublicResolver(tldContract, sldContract);
    }
}

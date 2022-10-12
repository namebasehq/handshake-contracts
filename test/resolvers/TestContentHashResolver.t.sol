// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

import "test/mocks/TestResolvers.sol";
import "test/mocks/MockHandshakeNft.sol";

contract TestContentHashResolver is Test {
    TestingContentHashResolver resolver;
    MockHandshakeNft tld;
    MockHandshakeNft sld;

    function setup() public {
        tld = new MockHandshakeNft();
        sld = new MockHandshakeNft();

        resolver = new TestingContentHashResolver(tld, sld);
    }
}

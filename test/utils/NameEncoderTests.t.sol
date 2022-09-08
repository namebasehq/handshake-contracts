// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

import "utils/BytesUtils.sol";
import { NameEncoder } from "utils/NameEncoder.sol";

contract NameEncoderTests is Test {
    using NameEncoder for string;
    using BytesUtils for bytes;

    function encodeName(string memory name)
        private
        pure
        returns (bytes memory, bytes32)
    {
        return name.dnsEncodeName();
    }

    function testDnsEncoding() public {
        (bytes memory dnsName, bytes32 node) = encodeName("aox.eth");
        // console.logBytes1(dnsName[0]);
        // console.logBytes1(dnsName[1]);
        assertEq(node, 0x81f536edca1dbdb9582598140d28a86010c4dbb395f128647f1add370d334d89);
    }
}

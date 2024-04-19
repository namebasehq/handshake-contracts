// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

import "src/contracts/ccip/OffchainResolver.sol";

contract TestOffchainResolver is Test {
    OffchainResolver resolver;
}

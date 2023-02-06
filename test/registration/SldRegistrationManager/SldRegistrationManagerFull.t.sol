// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import {Namehash} from "utils/Namehash.sol";
import "interfaces/ILabelValidator.sol";
import "contracts/SldRegistrationManager.sol";
import "mocks/MockGlobalRegistrationStrategy.sol";
import "mocks/MockLabelValidator.sol";
import "mocks/MockHandshakeTld.sol";
import "mocks/MockHandshakeSld.sol";
import "mocks/MockCommitIntent.sol";
import "mocks/MockRegistrationStrategy.sol";
import "mocks/MockGasGriefingRegistrationStrategy.sol";
import "src/utils/Namehash.sol";
import "structs/SldRegistrationDetail.sol";
import "mocks/MockUsdOracle.sol";
import "./SldRegistrationManagerBase.t.sol";

contract TestSldRegistrationManagerFullTests is TestSldRegistrationManagerBase {}

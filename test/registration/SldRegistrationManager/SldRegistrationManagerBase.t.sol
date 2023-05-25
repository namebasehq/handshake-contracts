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

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract TestSldRegistrationManagerBase is Test {
    SldRegistrationManager internal manager;
    using stdStorage for StdStorage;

    MockHandshakeSld sld;
    MockHandshakeTld tld;
    MockCommitIntent commitIntent;
    MockLabelValidator labelValidator;
    MockGlobalRegistrationStrategy globalStrategy;

    ISldRegistrationStrategy mockStrategy = new MockRegistrationStrategy(1 ether); // $1 per year

    fallback() external payable {}

    receive() external payable {}

    function setUp() public virtual {
        labelValidator = new MockLabelValidator(true);
        sld = new MockHandshakeSld();
        tld = new MockHandshakeTld();
        commitIntent = new MockCommitIntent(true);
        MockUsdOracle oracle = new MockUsdOracle(100000000); //$1
        globalStrategy = new MockGlobalRegistrationStrategy(true, true, 1 ether);
        SldRegistrationManager implementation = new SldRegistrationManager();

        TransparentUpgradeableProxy uups = new TransparentUpgradeableProxy(
            address(implementation),
            address(0x224455),
            bytes("")
        );

        manager = SldRegistrationManager(address(uups));

        manager.init(
            tld,
            sld,
            commitIntent,
            oracle,
            labelValidator,
            globalStrategy,
            address(this),
            address(this)
        );
    }

    function addMockOracle() internal {
        MockUsdOracle oracle = new MockUsdOracle(200000000000);
        manager.updatePriceOracle(oracle);
        //stdstore.target(address(manager)).sig("usdOracle()").checked_write(address(oracle));
    }

    function setUpLabelValidator() internal {
        ILabelValidator validator = new MockLabelValidator(true);
        manager.updateLabelValidator(validator);
    }

    function setUpGlobalStrategy(bool _canReg, bool _canRenew, uint256 _minPrice) internal {
        IGlobalRegistrationRules globalRules = new MockGlobalRegistrationStrategy(
            _canReg,
            _canRenew,
            _minPrice
        );
        manager.updateGlobalRegistrationStrategy(globalRules);
    }

    function setUpRegistrationStrategy(bytes32 _parentNamehash) internal {
        sld.setMockRegistrationStrategy(_parentNamehash, mockStrategy);
    }
}

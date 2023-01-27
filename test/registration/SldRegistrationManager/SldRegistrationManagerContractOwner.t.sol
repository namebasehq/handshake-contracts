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

contract TestSldRegistrationManagerContractOwnerTests is TestSldRegistrationManagerBase {
    function testUpdateLabelValidatorFromOwner_success() public {
        ILabelValidator validator = new MockLabelValidator(true);
        manager.updateLabelValidator(validator);

        assertEq(
            address(manager.labelValidator()),
            address(validator),
            "label validator not set correctly"
        );
    }

    function testUpdateUsdOracleFromOwner_pass() public {
        MockUsdOracle oracle = new MockUsdOracle(1);
        manager.updatePriceOracle(oracle);

        assertEq(address(manager.usdOracle()), address(oracle));
    }

    function testUpdateUsdOracleFromNotOwner_fail() public {
        MockUsdOracle oracle = new MockUsdOracle(1);
        vm.startPrank(address(0x112233));
        vm.expectRevert("Ownable: caller is not the owner");
        manager.updatePriceOracle(oracle);
    }

    function testUpdateLabelValidatorFromNotOwner_fail() public {
        ILabelValidator validator = new MockLabelValidator(true);
        vm.prank(address(0x420));
        vm.expectRevert("Ownable: caller is not the owner");
        manager.updateLabelValidator(validator);
    }

    function testSetGlobalRegistrationStrategyFromContractOwner_pass() public {
        IGlobalRegistrationRules globalRules = new MockGlobalRegistrationStrategy(false, 1 ether);
        manager.updateGlobalRegistrationStrategy(globalRules);

        assertEq(
            address(manager.globalStrategy()),
            address(globalRules),
            "global registration rules not set correctly"
        );
    }

    function testSetGlobalRegistrationStrategyFromNotContractOwner_fail() public {
        IGlobalRegistrationRules globalRules = new MockGlobalRegistrationStrategy(false, 1 ether);

        vm.startPrank(address(0x1234));
        vm.expectRevert("Ownable: caller is not the owner");
        manager.updateGlobalRegistrationStrategy(globalRules);
    }

    function testPurchaseSldToZeroAddress_expectSendToMsgSender() public {
        setUpLabelValidator();
        setUpGlobalStrategy(true, 1 ether);
        bytes32 parentNamehash = bytes32(uint256(0x226677));
        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);

        string memory label = "yo";
        bytes32 secret = 0x0;
        uint80 registrationLength = 500;

        address recipient = address(0);

        address sendingAddress = address(0x420);
        hoax(sendingAddress, 20 ether);
        vm.expectCall(
            address(manager.sld()),
            abi.encodeCall(manager.sld().registerSld, (sendingAddress, parentNamehash, label))
        );
        vm.startPrank(sendingAddress);
        manager.registerSld{value: (uint256(1 ether) / uint256(365)) * registrationLength + 137}(
            label,
            secret,
            registrationLength,
            parentNamehash,
            recipient
        );
    }

    function testSetHandshakeWalletAddressFromContractOwner_pass() public {
        address addr = address(0x225599);

        manager.updateHandshakePaymentAddress(addr);

        assertEq(manager.handshakeWalletPayoutAddress(), addr, "address not set");
    }

    function testSetHandshakeWalletAddressToZeroAddressFromContractOwner_fail() public {
        address addr = address(0x0);

        vm.expectRevert("cannot set to zero address");
        manager.updateHandshakePaymentAddress(addr);
    }

    function testSetHandshakeWalletAddressFromNotContractOwner_fail() public {
        address addr = address(0x225599);

        vm.prank(address(0x12234));
        vm.expectRevert("Ownable: caller is not the owner");
        manager.updateHandshakePaymentAddress(addr);
    }

    function testSetHandshakePercentCommisionFromContractOwner_pass() public {
        uint256 percent = 5;

        manager.updateHandshakePaymentPercent(percent);

        assertEq(manager.handshakePercentCommission(), percent, "percent not set");
    }

    function testSetHandshakePercentCommisionFromNotContractOwner_fail() public {
        uint256 percent = 8;
        uint256 currentValue = manager.handshakePercentCommission();

        vm.prank(address(0x12234));
        vm.expectRevert("Ownable: caller is not the owner");
        manager.updateHandshakePaymentPercent(percent);

        assertEq(manager.handshakePercentCommission(), currentValue, "percent set");
    }

    function testSetHandshakePercentCommisionFromContractOwnerSetOver10Percent_fail() public {
        uint256 percent = 11;

        uint256 currentValue = manager.handshakePercentCommission();

        vm.expectRevert("cannot set to more than 10 percent");
        manager.updateHandshakePaymentPercent(percent);

        assertEq(manager.handshakePercentCommission(), currentValue, "percent set");
    }
}

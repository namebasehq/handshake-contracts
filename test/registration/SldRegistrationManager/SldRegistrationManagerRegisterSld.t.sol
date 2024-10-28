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

contract TestSldRegistrationManagerRegisterSldTests is TestSldRegistrationManagerBase {
    using stdStorage for StdStorage;

    function setUp() public override {
        vm.warp(365 days);
        super.setUp();
    }

    function testPurchaseSldLabelValidatorReturnFalse_fail() public {
        ILabelValidator validator = new MockLabelValidator(false);
        manager.updateLabelValidator(validator);

        bytes32 parentNamehash = bytes32(uint256(0x4));

        setUpRegistrationStrategy(parentNamehash);
        setUpGlobalStrategy(true, false, 1 ether);

        string memory label = "yo";
        bytes32 secret = 0x0;
        uint80 registrationLength = 500;

        address recipient = address(0x5555);

        vm.prank(address(0x420));
        vm.expectRevert("invalid label");
        manager.registerWithCommit(label, secret, registrationLength, parentNamehash, recipient);
    }

    function testPurchaseSldGlobalRegistrationRulesReturnFalse_fail() public {
        setUpLabelValidator();
        bytes32 parentNamehash = bytes32(uint256(0x4));
        setUpRegistrationStrategy(parentNamehash);
        tld.register(address(this), uint256(parentNamehash));

        IGlobalRegistrationRules rules = new MockGlobalRegistrationStrategy(false, true, 1 ether);
        manager.updateGlobalRegistrationStrategy(rules);

        string memory label = "yo";
        bytes32 secret = 0x0;
        uint80 registrationLength = 500;

        address recipient = address(0x5555);

        vm.prank(address(0x420));
        vm.expectRevert("failed global strategy");
        manager.registerWithCommit(label, secret, registrationLength, parentNamehash, recipient);
    }

    function testMintSldFromAuthorisedWalletRepurchaseWhenExpired_success() public {
        ILabelValidator validator = new MockLabelValidator(true);
        manager.updateLabelValidator(validator);
        setUpGlobalStrategy(true, true, 1 ether);

        bytes32 parentNamehash = bytes32(uint256(0x4));
        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);

        string memory label = "yo";
        bytes32 secret = 0x0;
        uint80 registrationLength = 500;

        address recipient = address(0x5555);

        hoax(address(0x420), 4 ether);
        manager.registerWithCommit{value: 2 ether}(label, secret, registrationLength, parentNamehash, recipient);

        vm.warp(block.timestamp + (registrationLength * 86400) + 30 days + 1);

        vm.prank(address(0x420));
        manager.registerWithCommit{value: 2 ether}(label, secret, registrationLength, parentNamehash, recipient);
    }

    function testMintSldFromAuthorisedWalletRepurchaseWhenStillActive_fail() public {
        ILabelValidator validator = new MockLabelValidator(true);
        manager.updateLabelValidator(validator);

        bytes32 parentNamehash = bytes32(uint256(0x4));
        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);
        setUpGlobalStrategy(true, true, 1 ether);

        string memory label = "yo";
        bytes32 secret = 0x0;
        uint80 registrationLength = 500;

        address recipient = address(0x5555);

        hoax(address(0x420), 4 ether);
        manager.registerWithCommit{value: 2 ether}(label, secret, registrationLength, parentNamehash, recipient);

        vm.warp(block.timestamp + (registrationLength * 86400) - 10);

        vm.prank(address(0x420));
        vm.expectRevert("domain already registered");
        manager.registerWithCommit{value: 2 ether}(label, secret, registrationLength, parentNamehash, recipient);
    }

    function testPurchaseSldToOtherAddress() public {
        setUpLabelValidator();
        setUpGlobalStrategy(true, true, 1 ether);
        bytes32 parentNamehash = bytes32(uint256(0x55446677));
        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);
        string memory label = "yo";
        bytes32 secret = 0x0;
        uint80 registrationLength = 500;

        address recipient = address(0xbadbad);

        address sendingAddress = address(0x420);
        hoax(sendingAddress, 2 ether);
        vm.expectCall(
            address(manager.sld()), abi.encodeCall(manager.sld().registerSld, (recipient, parentNamehash, label))
        );
        vm.prank(sendingAddress);
        manager.registerWithCommit{value: 2 ether}(label, secret, registrationLength, parentNamehash, recipient);
    }

    function testPurchaseSldToOtherAddressThenBurn() public {
        setUpLabelValidator();
        setUpGlobalStrategy(true, true, 1 ether);
        bytes32 parentNamehash = bytes32(uint256(0x55446677));
        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);
        string memory label = "yo";
        bytes32 secret = 0x0;
        uint80 registrationLength = 500;

        address recipient = address(0xbadbad);

        address sendingAddress = address(0x420);
        hoax(sendingAddress, 2 ether);
        vm.expectCall(
            address(manager.sld()), abi.encodeCall(manager.sld().registerSld, (recipient, parentNamehash, label))
        );
        vm.startPrank(sendingAddress);
        manager.registerWithCommit{value: 2 ether}(label, secret, registrationLength, parentNamehash, recipient);

        bytes32 subhash = Namehash.getNamehash(parentNamehash, label);
        vm.expectCall(address(manager.sld()), abi.encodeCall(manager.sld().burnSld, (subhash)));
        manager.sld().burnSld(subhash);
    }

    function testPurchaseSldInvalidCommitIntent() public {
        setUpLabelValidator();
        setUpGlobalStrategy(true, true, 1 ether);
        bytes32 parentNamehash = bytes32(uint256(0x55446677));
        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);
        string memory label = "yo";
        bytes32 secret = 0x0;
        uint80 registrationLength = 500;

        address recipient = address(0xbadbad);

        MockCommitIntent intent = new MockCommitIntent(false);

        manager.updateCommitIntent(intent);

        address sendingAddress = address(0x420);
        hoax(sendingAddress, 2 ether);
        vm.expectRevert("No valid commit intent");
        manager.registerWithCommit{value: 2 ether}(label, secret, registrationLength, parentNamehash, recipient);
    }

    function testPurchaseSldRegistrationDisabled_fail() public {
        setUpLabelValidator();
        setUpGlobalStrategy(true, true, 1 ether);
        bytes32 parentNamehash = bytes32(uint256(0x55446677));
        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);
        string memory label = "yo";
        bytes32 secret = 0x0;
        uint80 registrationLength = 500;

        address recipient = address(0xbadbad);

        stdstore.target(address(mockStrategy)).sig("isEnabledBool()").checked_write(false);

        address sendingAddress = address(0x420);
        hoax(sendingAddress, 2 ether);
        vm.expectRevert("registration strategy disabled");
        manager.registerWithCommit{value: 2 ether}(label, secret, registrationLength, parentNamehash, recipient);
    }

    // owner of TLD should be able to register if the public registration is disabled
    function testPurchaseSldRegistrationDisabledFromOwner_success() public {
        setUpLabelValidator();
        setUpGlobalStrategy(true, true, 1 ether);
        bytes32 parentNamehash = bytes32(uint256(0x55446677));
        address owner = address(0x99);
        tld.register(owner, uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);
        string memory label = "yo";
        bytes32 secret = 0x0;
        uint80 registrationLength = 500;

        address recipient = address(0xbadbad);

        stdstore.target(address(mockStrategy)).sig("isEnabledBool()").checked_write(false);

        hoax(owner, 2 ether);
        manager.registerWithCommit{value: 2 ether}(label, secret, registrationLength, parentNamehash, recipient);
    }

    function testMintSingleDomainWithNoPriceStrategy_fail() public {
        setUpLabelValidator();
        setUpGlobalStrategy(true, true, 1 ether);

        string memory label = "yo";
        bytes32 secret = 0x0;
        uint80 registrationLength = 500;
        bytes32 parentNamehash = bytes32(uint256(0x55446677));

        address owner = address(0x99);
        tld.register(owner, uint256(parentNamehash));

        address recipient = address(0xbadbad);

        address sendingAddress = address(0x420);

        vm.prank(sendingAddress);
        vm.expectRevert();
        manager.registerWithCommit(label, secret, registrationLength, parentNamehash, recipient);
    }

    function testMintSingleDomainCheckHistory() public {
        setUpLabelValidator();
        setUpGlobalStrategy(true, true, 1 ether);

        string memory label = "yo";
        bytes32 secret = 0x0;
        uint80 registrationLength = 365;
        bytes32 parentNamehash = bytes32(uint256(0x55446677));
        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);

        address recipient = address(0xbadbad);

        address sendingAddress = address(0x420);
        hoax(sendingAddress, 20 ether);

        vm.expectCall(
            address(manager.sld()), abi.encodeCall(manager.sld().registerSld, (recipient, parentNamehash, label))
        );

        vm.startPrank(sendingAddress);
        manager.registerWithCommit{value: 1 ether + 1}(label, secret, registrationLength, parentNamehash, recipient);

        bytes32 sldNamehash = Namehash.getNamehash(parentNamehash, label);

        (uint80 actualRegistrationTime, uint80 actualRegistrationLength, uint96 actualRegistrationPrice) =
            manager.sldRegistrationHistory(sldNamehash);

        assertEq(actualRegistrationTime, block.timestamp, "registration time incorrect");
        assertEq(actualRegistrationLength, registrationLength * 1 days, "registration length incorrect");
        assertEq(actualRegistrationPrice, 1 ether, "registration price incorrect");

        uint80[10] memory pricing = manager.getTenYearGuarenteedPricing(sldNamehash);

        for (uint256 i; i < 10; i++) {
            //pricing should return back flat rate of 1 dollar per year regardless of length
            assertEq(pricing[i], 1 ether, "issue with historic pricing");
        }
    }

    //this test was crashing the test runner
    function testPurchaseSingleDomainGetRefundForExcess() public {
        string memory label = "";
        uint256 registrationLength = 365 * 2;
        bytes32 parentNamehash = Namehash.getTldNamehash("yoyo");

        uint256 annualCost = 2000 ether; //should be $4000 total

        ISldRegistrationStrategy strategy2 = new MockRegistrationStrategy(annualCost);

        sld.setMockRegistrationStrategy(parentNamehash, strategy2);
        tld.addRegistrationStrategy(parentNamehash, strategy2);

        setUpLabelValidator();
        setUpGlobalStrategy(true, true, 1 ether);
        addMockOracle();

        address claimant = address(0x6666);
        address tldOwner = address(0x464646);

        manager.updatePaymentAddress(address(0x57595351));

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.register(tldOwner, "yoyo");

        uint256 registrationTimestamp = block.timestamp;

        hoax(claimant, 2 ether + 1);
        manager.registerWithCommit{value: 2 ether + 1}( //should cost 2 ether
            label,
            0x0, //secret
            registrationLength,
            parentNamehash,
            claimant
        );
        vm.stopPrank();

        bytes32 namehash = Namehash.getNamehash(parentNamehash, label);

        (, uint80 RegistrationLength,) = manager.sldRegistrationHistory(namehash);

        uint80 newRegLength = 400;

        vm.warp(block.timestamp + 420);
        hoax(claimant, 1.095 ether + 1);
        vm.expectRevert("not enough ether");
        manager.renewSld{value: 1.095 ether + 1}(label, parentNamehash, newRegLength);

        hoax(claimant, 1.096 ether + 1);

        manager.renewSld{value: 1.096 ether + 1}(label, parentNamehash, newRegLength);

        (
            uint80 NewRegistrationTime,
            uint80 NewRegistrationLength, //uint96NewRegistrationPrice
        ) = manager.sldRegistrationHistory(namehash);

        assertEq(
            NewRegistrationLength, RegistrationLength + (newRegLength * 86400), "new registrationLength not correct"
        );

        assertEq(NewRegistrationTime, registrationTimestamp, "original registration time incorrect");
    }

    function testPurchaseSingleDomainFundsGetSentToOwnerAndHandshakeWallet() public {
        string memory label = "";
        uint256 registrationLength = 365;
        bytes32 parentNamehash = Namehash.getTldNamehash("yoyo");

        uint256 annualCost = 2000 ether; //should be $4000 total

        ISldRegistrationStrategy strategy2 = new MockRegistrationStrategy(annualCost);

        sld.setMockRegistrationStrategy(parentNamehash, strategy2);
        tld.addRegistrationStrategy(parentNamehash, strategy2);

        setUpLabelValidator();
        setUpGlobalStrategy(true, true, 1 ether);
        addMockOracle();

        address claimant = address(0x6666);
        address tldOwner = address(0x464646);

        address walletPayoutAddress = address(0x57595351);

        manager.updatePaymentAddress(walletPayoutAddress);
        manager.updatePaymentPercent(10);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.register(tldOwner, "yoyo");

        hoax(claimant, 1 ether);
        manager.registerWithCommit{value: 1 ether}(
            label,
            0x0, //secret
            registrationLength,
            parentNamehash,
            claimant
        );
        vm.stopPrank();

        assertEq(walletPayoutAddress.balance, 0.1 ether, "wallet balance not correct");

        uint80 newRegLength = 365 * 2;

        vm.warp(block.timestamp + 420);

        hoax(claimant, 2 ether + 1);

        manager.renewSld{value: 2 ether}(label, parentNamehash, newRegLength);

        // (
        //     uint80 NewRegistrationTime,
        //     uint80 NewRegistrationLength, //uint96NewRegistrationPrice

        // ) = manager.sldRegistrationHistory(namehash);

        assertEq(walletPayoutAddress.balance, 0.3 ether, "wallet balance not correct");
    }
}

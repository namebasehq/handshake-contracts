// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import {Namehash} from "utils/Namehash.sol";
import "contracts/HandshakeSld.sol";
import "utils/Namehash.sol";
import "interfaces/ITldClaimManager.sol";
import "interfaces/ISldRegistrationManager.sol";
import "test/mocks/MockClaimManager.sol";
import "test/mocks/MockCommitIntent.sol";
import "test/mocks/MockLabelValidator.sol";
import "test/mocks/MockHandshakeTld.sol";
import "test/mocks/MockMetadataService.sol";
import "test/mocks/MockRegistrationStrategy.sol";
import "test/mocks/MockUsdOracle.sol";
import "test/mocks/MockGlobalRegistrationStrategy.sol";
import "test/mocks/MockCommitIntent.sol";
import "test/mocks/MockSldRegistrationManager.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "interfaces/ICommitIntent.sol";
import "interfaces/ILabelValidator.sol";

contract TestHandshakeSld is Test {
    error MissingRegistrationStrategy();

    // test
    bytes32 constant TEST_TLD_NAMEHASH =
        0x04f740db81dc36c853ab4205bddd785f46e79ccedca351fc6dfcbd8cc9a33dd6;
    // test.test
    bytes32 constant TEST_sld_NAMEHASH =
        0x28f4f6752878f66fd9e3626dc2a299ee01cfe269be16e267e71046f1022271cb;
    // test.test.test
    bytes32 constant TEST_SUB_NAMEHASH =
        0xab4320f3c1dd20a2fc23e7b0dda6f37afbf916136c4797a99caad59e740d9494;

    using stdStorage for StdStorage;

    HandshakeSld sld;
    MockHandshakeTld tld;
    MockSldRegistrationManager manager;
    MockLabelValidator labelValidator;
    MockMetadataService metadata;

    function setUp() public {
        metadata = new MockMetadataService("base_uri");
        labelValidator = new MockLabelValidator(true);
        tld = new MockHandshakeTld();
        manager = new MockSldRegistrationManager(
            tld,
            new MockGlobalRegistrationStrategy(true, 1 ether)
        );
        sld = new HandshakeSld(tld);
        sld.setRegistrationManager(manager);
        sld.setMetadataContract(metadata);
    }

    function addSldRegistrationHistory(bytes32 _sldNamehash, uint256 _registrationLength) private {
        uint128[10] memory arr;

        manager.addSldDetail(
            _sldNamehash,
            uint80(block.timestamp),
            uint80(_registrationLength),
            uint96(0),
            arr
        );
    }

    function testMintSldFromRegistryAddress_success() public {
        vm.startPrank(address(manager));

        address to = address(0x123456789);
        bytes32 tldNamehash = bytes32(uint256(0x224466));
        string memory label = "label12345";
        bytes32 sldNamehash = Namehash.getNamehash(tldNamehash, label);
        addSldRegistrationHistory(sldNamehash, 100);

        sld.registerSld(to, tldNamehash, label);

        assertEq(sld.ownerOf(uint256(sldNamehash)), to, "not owner of token");
        assertEq(sld.balanceOf(to), 1, "balance incorrect");
    }

    function testMintSldFromNotRegistryAddress_fail() public {
        vm.startPrank(address(0x66666));

        address to = address(0x123456789);
        bytes32 tldNamehash = bytes32(uint256(0x224466));
        string memory label = "hiya";

        vm.expectRevert("not authorised");
        sld.registerSld(to, tldNamehash, label);
    }

    function testMintDuplicateSld_fail() public {
        vm.startPrank(address(manager));

        address to = address(0x123456789);
        bytes32 tldNamehash = bytes32(uint256(0x224466));
        string memory label = "hello";
        bytes32 sldNamehash = Namehash.getNamehash(tldNamehash, label);
        addSldRegistrationHistory(sldNamehash, 100);
        sld.registerSld(to, tldNamehash, label);

        assertEq(sld.ownerOf(uint256(sldNamehash)), to, "not owner of token");
        assertEq(sld.balanceOf(to), 1, "balance incorrect");

        vm.expectRevert("ERC721: token already minted");
        sld.registerSld(to, tldNamehash, label);
    }

    function testCheckParentNamehashIsCorrectAfterMint() public {
        vm.startPrank(address(manager));

        address to = address(0x123456789);
        bytes32 tldNamehash = bytes32(uint256(0x224466));
        string memory label = "onemoretime";
        bytes32 sldNamehash = Namehash.getNamehash(tldNamehash, label);

        addSldRegistrationHistory(sldNamehash, 100);

        sld.registerSld(to, tldNamehash, label);

        assertEq(sld.ownerOf(uint256(sldNamehash)), to, "not owner of token");
        assertEq(sld.balanceOf(to), 1, "balance incorrect");
    }

    function testCheckLabelToNamehashIsCorrectAfterMint() public {
        vm.startPrank(address(manager));
        console.log("manager address", address(manager));
        address to = address(0x123456789);
        bytes32 tldNamehash = bytes32(uint256(0x224466));
        string memory label = "yo123";
        bytes32 sldNamehash = Namehash.getNamehash(tldNamehash, label);

        uint256 registrationLength = 100 days;
        uint128[10] memory arr;

        manager.addSldDetail(
            sldNamehash,
            uint80(block.timestamp),
            uint80(registrationLength),
            uint96(0),
            arr
        );

        tld.register(address(manager), uint256(tldNamehash));

        sld.registerSld(to, tldNamehash, label);

        assertEq(
            sld.namehashToParentMap(sldNamehash),
            tldNamehash,
            "namehash for parent incorrect"
        );
    }

    function testSetRoyaltyPaymentAddressForTldFromTldOwnerAddress() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address payoutAddress = address(0x22886644);
        string memory label = "thislabel";
        bytes32 parent_hash = Namehash.getTldNamehash(tldName);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.register(tldOwner, tldName);

        bytes32 sldNamehash = Namehash.getNamehash(parent_hash, label);
        addSldRegistrationHistory(sldNamehash, 100);
        vm.prank(address(manager));
        sld.registerSld(sldOwner, parent_hash, label);

        // test.test
        uint256 expectedsldId = uint256(sldNamehash);
        uint256 tldId = uint256(parent_hash);

        vm.prank(tldOwner);
        sld.setRoyaltyPayoutAddress(tldId, payoutAddress);
        (address _addr, ) = sld.royaltyInfo(expectedsldId, 100);
        assertEq(_addr, payoutAddress);
        vm.stopPrank();
    }

    function testSetRoyaltyPaymentAddressForTldNotSet_ShouldReturnTldOwner() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        string memory label = "thisisthelabel";
        bytes32 parent_hash = Namehash.getTldNamehash(tldName);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.register(tldOwner, tldName);

        bytes32 sldNamehash = Namehash.getNamehash(parent_hash, label);
        addSldRegistrationHistory(sldNamehash, 100);
        vm.prank(address(manager));
        sld.registerSld(sldOwner, parent_hash, label);

        // test.test
        uint256 expectedsldId = uint256(sldNamehash);

        (address _addr, ) = sld.royaltyInfo(expectedsldId, 100);
        assertEq(_addr, tldOwner);
        vm.stopPrank();
    }

    function testSetRoyaltyPaymentAddressThenTransferTld_AddressShouldResetToNewOwner() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address payoutAddress = address(0x22886644);
        string memory label = "heeey";
        bytes32 parent_hash = Namehash.getTldNamehash(tldName);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.register(tldOwner, tldName);

        bytes32 sldNamehash = Namehash.getNamehash(parent_hash, label);
        addSldRegistrationHistory(sldNamehash, 100);
        vm.prank(address(manager));
        sld.registerSld(sldOwner, parent_hash, label);

        // test.test
        uint256 expectedsldId = uint256(sldNamehash);

        uint256 tldId = uint256(parent_hash);

        address newTldOwner = address(0x553311);

        vm.startPrank(tldOwner);
        sld.setRoyaltyPayoutAddress(tldId, payoutAddress);
        (address _addr, ) = sld.royaltyInfo(expectedsldId, 100);
        assertEq(_addr, payoutAddress);
        tld.safeTransferFrom(tldOwner, newTldOwner, tldId);
        vm.stopPrank();

        (_addr, ) = sld.royaltyInfo(expectedsldId, 100);
        assertEq(_addr, newTldOwner);
    }

    function testSetRoyaltyPaymentAddressForTldFromTldOwnerApprovedAddress() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address payoutAddress = address(0x22886644);
        string memory label = "yoooo";
        bytes32 parent_hash = Namehash.getTldNamehash(tldName);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.register(tldOwner, tldName);

        bytes32 sldNamehash = Namehash.getNamehash(parent_hash, label);
        addSldRegistrationHistory(sldNamehash, 100);
        vm.prank(address(manager));
        sld.registerSld(sldOwner, parent_hash, label);

        // test.test
        uint256 expectedsldId = uint256(sldNamehash);

        uint256 tldId = uint256(parent_hash);

        address approvedAddress = address(0x558822);

        vm.prank(tldOwner);
        tld.setApprovalForAll(approvedAddress, true);
        vm.startPrank(approvedAddress);
        sld.setRoyaltyPayoutAddress(tldId, payoutAddress);
        (address _addr, ) = sld.royaltyInfo(expectedsldId, 100);
        assertEq(_addr, payoutAddress);
        vm.stopPrank();
    }

    function testSetRoyaltyPaymentAddressForTldFromNotTldOwnerAddress_ExpectFail() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address payoutAddress = address(0x22886644);
        string memory label = "yoyoyo";
        bytes32 parent_hash = Namehash.getTldNamehash(tldName);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.register(tldOwner, tldName);

        bytes32 sldNamehash = Namehash.getNamehash(parent_hash, label);
        addSldRegistrationHistory(sldNamehash, 100);
        vm.startPrank(address(manager));
        sld.registerSld(sldOwner, parent_hash, label);
        vm.stopPrank();

        uint256 tldId = uint256(parent_hash);

        address notTldOwner = address(0x9988332211);
        vm.startPrank(notTldOwner);
        vm.expectRevert("not authorised");
        sld.setRoyaltyPayoutAddress(tldId, payoutAddress);

        vm.stopPrank();
    }

    function testSetRoyaltyPaymentAmountForTldFromTldOwnerAddress_pass() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        string memory label = "testtest";
        bytes32 parent_hash = Namehash.getTldNamehash(tldName);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.register(tldOwner, tldName);

        bytes32 sldNamehash = Namehash.getNamehash(parent_hash, label);
        addSldRegistrationHistory(sldNamehash, 100);
        vm.prank(address(manager));
        sld.registerSld(sldOwner, parent_hash, label);

        // test.test
        uint256 expectedsldId = uint256(sldNamehash);

        uint256 tldId = uint256(parent_hash);

        uint256 royaltyPercent = 10;

        vm.prank(tldOwner);
        sld.setRoyaltyPayoutAmount({_id: tldId, _amount: royaltyPercent});
        (, uint256 amount) = sld.royaltyInfo(expectedsldId, 100);

        assertEq(amount, royaltyPercent, "incorrect royalty amount");
        vm.stopPrank();
    }

    function testSetRoyaltyPaymentAmountForTldNotSet_ShouldReturnZero() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);

        bytes32 parent_hash = Namehash.getTldNamehash(tldName);
        string memory label = "123test";
        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.register(tldOwner, tldName);

        bytes32 sldNamehash = Namehash.getNamehash(parent_hash, label);

        addSldRegistrationHistory(sldNamehash, 100);
        vm.prank(address(manager));
        sld.registerSld(sldOwner, parent_hash, label);

        // test.test
        uint256 expectedsldId = uint256(sldNamehash);

        (, uint256 amount) = sld.royaltyInfo(expectedsldId, 100);

        assertEq(amount, 0, "incorrect royalty amount, should be zero");
        vm.stopPrank();
    }

    function testSetRoyaltyPaymentAmountForTldFromTldOwnerApprovedAddress() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        string memory label = "test";
        bytes32 parent_hash = Namehash.getTldNamehash(tldName);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.register(tldOwner, tldName);

        bytes32 sldNamehash = Namehash.getNamehash(parent_hash, label);
        addSldRegistrationHistory(sldNamehash, 100);
        vm.prank(address(manager));
        sld.registerSld(sldOwner, parent_hash, label);

        // test.test
        uint256 expectedsldId = uint256(sldNamehash);

        assertEq(expectedsldId, uint256(TEST_sld_NAMEHASH));

        uint256 tldId = uint256(parent_hash);
        assertEq(tldId, uint256(TEST_TLD_NAMEHASH));

        address approvedAddress = address(0x558822);

        vm.prank(tldOwner);
        tld.setApprovalForAll(approvedAddress, true);
        vm.startPrank(approvedAddress);
        uint256 royaltyPercent = 1;
        sld.setRoyaltyPayoutAmount(tldId, royaltyPercent);

        (, uint256 amount) = sld.royaltyInfo(expectedsldId, 300);

        assertEq(amount, 3, "incorrect royalty amount");

        vm.stopPrank();
    }

    function testSetRoyaltyPaymentAmountForTldFromNotTldOwnerAddress_ExpectFail() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address payoutAddress = address(0x22886644);
        string memory label = "test";
        bytes32 parent_hash = Namehash.getTldNamehash(tldName);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.register(tldOwner, tldName);

        bytes32 sldNamehash = Namehash.getNamehash(parent_hash, label);
        addSldRegistrationHistory(sldNamehash, 100);
        vm.prank(address(manager));
        sld.registerSld(sldOwner, parent_hash, label);

        // test.test
        uint256 expectedsldId = uint256(sldNamehash);

        assertEq(expectedsldId, uint256(TEST_sld_NAMEHASH));

        uint256 tldId = uint256(parent_hash);
        assertEq(tldId, uint256(TEST_TLD_NAMEHASH));

        address notTldOwner = address(0x558822);

        vm.startPrank(notTldOwner);
        vm.expectRevert("not authorised");
        sld.setRoyaltyPayoutAddress(tldId, payoutAddress);

        vm.stopPrank();
    }

    function testSetRoyaltyPaymentAmountForTldFromTldOwnerAddressOver10Percent_expectFail() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        string memory label = "test";
        bytes32 parent_hash = Namehash.getTldNamehash(tldName);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.register(tldOwner, tldName);

        bytes32 sldNamehash = Namehash.getNamehash(parent_hash, label);
        addSldRegistrationHistory(sldNamehash, 100);
        vm.prank(address(manager));
        sld.registerSld(sldOwner, parent_hash, label);

        // test.test
        uint256 expectedsldId = uint256(sldNamehash);

        assertEq(expectedsldId, uint256(TEST_sld_NAMEHASH));

        uint256 tldId = uint256(parent_hash);
        assertEq(tldId, uint256(TEST_TLD_NAMEHASH));

        uint256 royaltyPercent = 11;

        vm.startPrank(tldOwner);
        vm.expectRevert("10% maximum royalty on SLD");
        sld.setRoyaltyPayoutAmount({_id: tldId, _amount: royaltyPercent});
        (, uint256 amount) = sld.royaltyInfo(expectedsldId, 100);
        assertEq(amount, 0);
        vm.stopPrank();
    }

    function testExpiredTokenRevertsOnOwnerOf() public {
        address to = address(0x123456789);
        bytes32 tldNamehash = bytes32(uint256(0x224466));
        string memory label = "test123";
        bytes32 sldNamehash = Namehash.getNamehash(tldNamehash, label);

        uint256 registrationLength = 100 days;
        uint128[10] memory arr;

        manager.addSldDetail(
            sldNamehash,
            uint80(block.timestamp),
            uint80(registrationLength),
            uint96(0),
            arr
        );

        stdstore.target(address(sld)).sig("registrationManager()").checked_write(address(manager));

        vm.startPrank(address(manager));

        sld.registerSld(to, tldNamehash, label);

        vm.warp(block.timestamp + registrationLength - 1);
        assertEq(sld.ownerOf(uint256(sldNamehash)), to, "owner of sld not correct");

        vm.warp(block.timestamp + 1);

        vm.expectRevert("sld expired");
        sld.ownerOf(uint256(sldNamehash));
    }

    function testExpiredTokenReturnsFalseUsingExists() public {
        address to = address(0x123456789);
        bytes32 tldNamehash = bytes32(uint256(0x224466));
        string memory label = "test123";
        bytes32 sldNamehash = Namehash.getNamehash(tldNamehash, label);

        uint256 registrationLength = 100 days;
        uint128[10] memory arr;

        manager.addSldDetail(
            sldNamehash,
            uint80(block.timestamp),
            uint80(registrationLength),
            uint96(0),
            arr
        );

        stdstore.target(address(sld)).sig("registrationManager()").checked_write(address(manager));

        vm.startPrank(address(manager));

        sld.registerSld(to, tldNamehash, label);

        vm.warp(block.timestamp + registrationLength - 1);
        assertEq(sld.ownerOf(uint256(sldNamehash)), to, "owner of sld not correct");

        assertTrue(sld.exists(uint256(sldNamehash)));

        vm.warp(block.timestamp + 1);

        assertFalse(sld.exists(uint256(sldNamehash)));
    }

    function testExpiredTokenTransfer_fail() public {
        address to = address(0x123456789);
        bytes32 tldNamehash = bytes32(uint256(0x224466));
        string memory label = "test123";
        bytes32 sldNamehash = Namehash.getNamehash(tldNamehash, label);

        uint256 registrationLength = 100 days;
        uint128[10] memory arr;

        manager.addSldDetail(
            sldNamehash,
            uint80(block.timestamp),
            uint80(registrationLength),
            uint96(0),
            arr
        );

        stdstore.target(address(sld)).sig("registrationManager()").checked_write(address(manager));

        vm.prank(address(manager));
        sld.registerSld(to, tldNamehash, label);

        vm.warp(block.timestamp + registrationLength - 1);
        assertEq(sld.ownerOf(uint256(sldNamehash)), to, "owner of sld not correct");

        address newAddress = address(0x97531);

        vm.prank(to);
        sld.safeTransferFrom(to, newAddress, uint256(sldNamehash));

        assertEq(sld.ownerOf(uint256(sldNamehash)), newAddress, "owner of sld not correct");

        vm.warp(block.timestamp + 1);

        vm.startPrank(newAddress);
        vm.expectRevert("sld expired");
        sld.safeTransferFrom(newAddress, address(0x888), uint256(sldNamehash));

        vm.expectRevert("sld expired");
        sld.transferFrom(newAddress, address(0x888), uint256(sldNamehash));

        assertFalse(sld.exists(uint256(sldNamehash)));
    }

    function testExpiredTokenRemintToDifferentWallet_success() public {
        address to = address(0x123456789);
        address to2 = address(0x6942069);
        bytes32 tldNamehash = bytes32(uint256(0x224466));
        string memory label = "testing";
        bytes32 sldNamehash = Namehash.getNamehash(tldNamehash, label);

        uint256 registrationLength = 100 days;
        uint128[10] memory arr;

        manager.addSldDetail(
            sldNamehash,
            uint80(block.timestamp),
            uint80(registrationLength),
            uint96(0),
            arr
        );

        stdstore.target(address(sld)).sig("registrationManager()").checked_write(address(manager));

        vm.startPrank(address(manager));

        sld.registerSld(to, tldNamehash, label);

        vm.warp(block.timestamp + registrationLength + 1);

        sld.registerSld(to2, tldNamehash, label);

        //simulate updating the registration history details
        manager.addSldDetail(
            sldNamehash,
            uint80(block.timestamp),
            uint80(registrationLength),
            uint96(0),
            arr
        );

        assertEq(sld.ownerOf(uint256(sldNamehash)), to2, "owner of token not correct");
        assertEq(sld.balanceOf(to), 0, "owner 1 should have zero balance");
        assertEq(sld.balanceOf(to2), 1, "owner 2 should have 1 balance");
    }

    function testMintSldCheckNameReturnsCorrectly_success() public {
        vm.startPrank(address(manager));

        address to = address(0x123456789);
        string memory tldLabel = "testingtesting123";
        tld.setLabel(tldLabel);
        bytes32 tldNamehash = Namehash.getTldNamehash(tldLabel);
        string memory label = "label12345";
        bytes32 sldNamehash = Namehash.getNamehash(tldNamehash, label);
        addSldRegistrationHistory(sldNamehash, 100);

        sld.registerSld(to, tldNamehash, label);

        string memory expectedDomain = string(abi.encodePacked(label, ".", tldLabel));

        assertEq(sld.name(sldNamehash), expectedDomain, "domain name not correct");
    }

    function testMintSldCheckResolverSet_success() public {
        IResolver resolver = IResolver(address(0x1234));
        vm.prank(address(this));
        sld.setDefaultResolver(resolver);

        vm.startPrank(address(manager));

        address to = address(0x123456789);
        string memory tldLabel = "testingtesting123";
        tld.setLabel(tldLabel);
        bytes32 tldNamehash = Namehash.getTldNamehash(tldLabel);
        string memory label = "label12345";
        bytes32 sldNamehash = Namehash.getNamehash(tldNamehash, label);
        addSldRegistrationHistory(sldNamehash, 100);

        sld.registerSld(to, tldNamehash, label);

        assertEq(
            address(sld.tokenResolverMap(sldNamehash)),
            address(resolver),
            "resolver address incorrect"
        );
    }

    function testMintSldCheckResolverSetDefaultChangedOldResolverDoesNotChange_success() public {
        IResolver resolver = IResolver(address(0x1234));
        IResolver resolver2 = IResolver(address(0x1235));

        vm.prank(address(this));
        sld.setDefaultResolver(resolver);

        address to = address(0x123456789);
        string memory tldLabel = "testingtesting123";
        tld.setLabel(tldLabel);
        bytes32 tldNamehash = Namehash.getTldNamehash(tldLabel);
        string memory label = "label12345";
        string memory label2 = "label2";
        bytes32 sldNamehash = Namehash.getNamehash(tldNamehash, label);
        bytes32 sldNamehash2 = Namehash.getNamehash(tldNamehash, label2);
        addSldRegistrationHistory(sldNamehash, 100);

        vm.prank(address(manager));
        sld.registerSld(to, tldNamehash, label);

        vm.prank(address(this));
        sld.setDefaultResolver(resolver2);

        vm.prank(address(manager));
        sld.registerSld(to, tldNamehash, label2);

        assertEq(
            address(sld.tokenResolverMap(sldNamehash)),
            address(resolver),
            "resolver 1 address incorrect"
        );
        assertEq(
            address(sld.tokenResolverMap(sldNamehash2)),
            address(resolver2),
            "resolver 2 address incorrect"
        );
    }
}

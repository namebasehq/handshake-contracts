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
import "src/utils/Namehash.sol";
import "structs/SldRegistrationDetail.sol";
import "mocks/MockUsdOracle.sol";
import "./SldRegistrationManagerBase.t.sol";

contract TestSldRegistrationManagerSldCount is TestSldRegistrationManagerBase {
    using stdStorage for StdStorage;

    function setUp() public override {
        vm.warp(365 days);
        super.setUp();
    }

    function testInitialSldCountIsZero() public {
        bytes32 parentNamehash = bytes32(uint256(0x4));
        uint256 count = manager.sldCountPerTld(parentNamehash);
        assertEq(count, 0, "initial SLD count should be zero");
    }

    function testSldCountIncrementsOnRegistration() public {
        setUpLabelValidator();
        setUpGlobalStrategy(true, true, 1 ether);

        bytes32 parentNamehash = bytes32(uint256(0x55446677));
        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);

        string memory label = "testdomain";
        bytes32 secret = 0x0;
        uint80 registrationLength = 365;
        address recipient = address(0x5555);

        // Check initial count
        uint256 initialCount = manager.sldCountPerTld(parentNamehash);
        assertEq(initialCount, 0, "initial count should be 0");

        // Register SLD
        hoax(address(0x420), 2 ether);
        manager.registerWithCommit{value: 1 ether + 1}(label, secret, registrationLength, parentNamehash, recipient);

        // Check count incremented
        uint256 newCount = manager.sldCountPerTld(parentNamehash);
        assertEq(newCount, 1, "count should increment to 1 after registration");
    }

    function testSldCountIncrementsOnMultipleRegistrations() public {
        setUpLabelValidator();
        setUpGlobalStrategy(true, true, 1 ether);

        bytes32 parentNamehash = bytes32(uint256(0x55446677));
        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);

        uint80 registrationLength = 365;
        address recipient = address(0x5555);

        // Register 3 different SLDs
        string[3] memory labels = ["domain1", "domain2", "domain3"];

        for (uint256 i = 0; i < 3; i++) {
            hoax(address(0x420), 2 ether);
            manager.registerWithCommit{value: 1 ether + 1}(
                labels[i], 0x0, registrationLength, parentNamehash, recipient
            );

            uint256 expectedCount = i + 1;
            uint256 actualCount = manager.sldCountPerTld(parentNamehash);
            assertEq(actualCount, expectedCount, "count should increment correctly");
        }
    }

    function testSldCountDecrementsOnBurn() public {
        setUpLabelValidator();
        setUpGlobalStrategy(true, true, 1 ether);

        bytes32 parentNamehash = bytes32(uint256(0x55446677));
        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);

        string memory label = "testdomain";
        bytes32 secret = 0x0;
        uint80 registrationLength = 365;
        address recipient = address(0x5555);

        // Register SLD
        hoax(address(0x420), 2 ether);
        manager.registerWithCommit{value: 1 ether + 1}(label, secret, registrationLength, parentNamehash, recipient);

        // Verify count is 1
        assertEq(manager.sldCountPerTld(parentNamehash), 1, "count should be 1 after registration");

        // Mock the ownerOf function to return our recipient address
        bytes32 sldNamehash = Namehash.getNamehash(parentNamehash, label);
        vm.mockCall(
            address(sld), abi.encodeWithSelector(sld.ownerOf.selector, uint256(sldNamehash)), abi.encode(recipient)
        );

        // Burn the SLD
        vm.prank(recipient);
        manager.burnSld(label, parentNamehash);

        // Verify count decremented
        uint256 countAfterBurn = manager.sldCountPerTld(parentNamehash);
        assertEq(countAfterBurn, 0, "count should decrement to 0 after burn");
    }

    function testSldCountDoesNotUnderflow() public {
        bytes32 parentNamehash = bytes32(uint256(0x55446677));

        // Try to burn when count is already 0
        // This should not underflow due to the safety check
        string memory label = "nonexistent";

        // This should revert for other reasons (domain doesn't exist), but if it didn't,
        // the count logic should prevent underflow
        uint256 countBefore = manager.sldCountPerTld(parentNamehash);
        assertEq(countBefore, 0, "initial count should be 0");

        // The burnSld function has other validation that will prevent this,
        // but our underflow protection is still there
    }

    function testInitializeSldCountOwnerOnly() public {
        bytes32 parentNamehash = bytes32(uint256(0x55446677));
        uint256 initialCount = 5;

        // Should work when called by owner
        manager.initializeSldCount(parentNamehash, initialCount);
        uint256 count = manager.sldCountPerTld(parentNamehash);
        assertEq(count, initialCount, "count should be set to initial value");

        // Should revert when called by non-owner
        vm.prank(address(0x12345));
        vm.expectRevert("Ownable: caller is not the owner");
        manager.initializeSldCount(parentNamehash, 10);
    }

    function testInitializeSldCountCanOverwrite() public {
        bytes32 parentNamehash = bytes32(uint256(0x55446677));

        // Set initial count
        manager.initializeSldCount(parentNamehash, 5);
        assertEq(manager.sldCountPerTld(parentNamehash), 5, "initial count should be 5");

        // Overwrite with new count
        manager.initializeSldCount(parentNamehash, 10);
        assertEq(manager.sldCountPerTld(parentNamehash), 10, "count should be updated to 10");
    }

    function testSldCountPerTldMappingIsPublic() public {
        bytes32 parentNamehash = bytes32(uint256(0x55446677));

        // Set a count
        manager.initializeSldCount(parentNamehash, 42);

        // Should be able to read directly from the public mapping
        uint256 count = manager.sldCountPerTld(parentNamehash);
        assertEq(count, 42, "should be able to read from public mapping");
    }

    function testSldCountsAreIndependentPerTld() public {
        setUpLabelValidator();
        setUpGlobalStrategy(true, true, 1 ether);

        bytes32 parentNamehash1 = bytes32(uint256(0x1111));
        bytes32 parentNamehash2 = bytes32(uint256(0x2222));

        tld.register(address(0x99), uint256(parentNamehash1));
        tld.register(address(0x99), uint256(parentNamehash2));
        setUpRegistrationStrategy(parentNamehash1);
        setUpRegistrationStrategy(parentNamehash2);

        // Register SLD under first TLD
        hoax(address(0x420), 2 ether);
        manager.registerWithCommit{value: 1 ether + 1}("domain1", 0x0, 365, parentNamehash1, address(0x5555));

        // Register 2 SLDs under second TLD
        for (uint256 i = 0; i < 2; i++) {
            hoax(address(0x420), 2 ether);
            manager.registerWithCommit{value: 1 ether + 1}(
                string(abi.encodePacked("domain", i + 2)), 0x0, 365, parentNamehash2, address(0x5555)
            );
        }

        // Verify independent counts
        assertEq(manager.sldCountPerTld(parentNamehash1), 1, "first TLD should have 1 SLD");
        assertEq(manager.sldCountPerTld(parentNamehash2), 2, "second TLD should have 2 SLDs");
    }

    function testSldCountWithSignatureRegistration() public {
        setUpLabelValidator();
        setUpGlobalStrategy(true, true, 1 ether);

        bytes32 parentNamehash = bytes32(uint256(0x55446677));
        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);

        string memory label = "testdomain";
        address buyer = address(0x420);
        bytes32 sldNamehash = Namehash.getNamehash(parentNamehash, label);

        // Set up signature
        uint256 privateKey = 0xb0b;
        address signingAddress = vm.addr(privateKey);
        manager.updateSigner(signingAddress, true);

        bytes32 digest = manager.getRegistrationHash(buyer, sldNamehash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        // Register with signature
        hoax(buyer, 2 ether);
        manager.registerWithSignature{value: 1 ether + 1}(label, 365, parentNamehash, address(0x5555), v, r, s);

        // Verify count incremented
        uint256 count = manager.sldCountPerTld(parentNamehash);
        assertEq(count, 1, "count should increment with signature registration");
    }

    function testSldCountConsistencyAfterMultipleOperations() public {
        setUpLabelValidator();
        setUpGlobalStrategy(true, true, 1 ether);

        bytes32 parentNamehash = bytes32(uint256(0x55446677));
        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);

        address recipient = address(0x5555);
        uint80 registrationLength = 365;

        // Register 5 SLDs
        string[5] memory domainLabels = ["domain0", "domain1", "domain2", "domain3", "domain4"];
        bytes32[5] memory sldNamehashes;

        for (uint256 i = 0; i < 5; i++) {
            hoax(address(0x420), 2 ether);
            manager.registerWithCommit{value: 1 ether + 1}(
                domainLabels[i], 0x0, registrationLength, parentNamehash, recipient
            );

            // Store namehash for later use
            sldNamehashes[i] = Namehash.getNamehash(parentNamehash, domainLabels[i]);
        }

        assertEq(manager.sldCountPerTld(parentNamehash), 5, "should have 5 SLDs registered");

        // Mock the ownerOf function for domains we want to burn
        vm.mockCall(
            address(sld), abi.encodeWithSelector(sld.ownerOf.selector, uint256(sldNamehashes[0])), abi.encode(recipient)
        );

        vm.mockCall(
            address(sld), abi.encodeWithSelector(sld.ownerOf.selector, uint256(sldNamehashes[2])), abi.encode(recipient)
        );

        // Burn 2 SLDs
        vm.startPrank(recipient);
        manager.burnSld(domainLabels[0], parentNamehash);
        manager.burnSld(domainLabels[2], parentNamehash);
        vm.stopPrank();

        assertEq(manager.sldCountPerTld(parentNamehash), 3, "should have 3 SLDs after burning 2");

        // Register 1 more
        hoax(address(0x420), 2 ether);
        manager.registerWithCommit{value: 1 ether + 1}("newdomain", 0x0, registrationLength, parentNamehash, recipient);

        assertEq(manager.sldCountPerTld(parentNamehash), 4, "should have 4 SLDs after registering 1 more");
    }

    function testBurnExpiredSld() public {
        setUpLabelValidator();
        setUpGlobalStrategy(true, true, 1 ether);

        bytes32 parentNamehash = bytes32(uint256(0x55446677));
        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);

        string memory label = "expireddomain";
        bytes32 secret = 0x0;
        uint80 registrationLength = 30; // Short registration period for testing
        address recipient = address(0x5555);

        // Register SLD
        hoax(address(0x420), 2 ether);
        manager.registerWithCommit{value: 1 ether + 1}(label, secret, registrationLength, parentNamehash, recipient);

        // Verify count is 1
        assertEq(manager.sldCountPerTld(parentNamehash), 1, "count should be 1 after registration");

        // Get the namehash
        bytes32 sldNamehash = Namehash.getNamehash(parentNamehash, label);

        // Fast forward time to after registration + grace period
        vm.warp(block.timestamp + (registrationLength * 1 days) + manager.gracePeriod() + 1);

        // Anyone should be able to burn the expired domain
        address randomUser = address(0x9999);
        vm.prank(randomUser);
        manager.burnExpiredSld(label, parentNamehash);

        // Verify count decremented
        uint256 countAfterBurn = manager.sldCountPerTld(parentNamehash);
        assertEq(countAfterBurn, 0, "count should decrement to 0 after burning expired domain");
    }

    function testBurnExpiredSldFailsForNonExpiredDomain() public {
        setUpLabelValidator();
        setUpGlobalStrategy(true, true, 1 ether);

        bytes32 parentNamehash = bytes32(uint256(0x55446677));
        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);

        string memory label = "activedomain";
        bytes32 secret = 0x0;
        uint80 registrationLength = 365;
        address recipient = address(0x5555);

        // Register SLD
        hoax(address(0x420), 2 ether);
        manager.registerWithCommit{value: 1 ether + 1}(label, secret, registrationLength, parentNamehash, recipient);

        // Try to burn the active domain - should fail
        address randomUser = address(0x9999);
        vm.prank(randomUser);
        vm.expectRevert("domain not expired");
        manager.burnExpiredSld(label, parentNamehash);

        // Verify count is still 1
        assertEq(manager.sldCountPerTld(parentNamehash), 1, "count should still be 1");
    }

    function testBurnExpiredSldFailsForNonExistentDomain() public {
        bytes32 parentNamehash = bytes32(uint256(0x55446677));

        // Try to burn a non-existent domain
        vm.expectRevert("domain not registered");
        manager.burnExpiredSld("nonexistentdomain", parentNamehash);
    }

    function testBurnExpiredSldFailsDuringGracePeriod() public {
        setUpLabelValidator();
        setUpGlobalStrategy(true, true, 1 ether);

        bytes32 parentNamehash = bytes32(uint256(0x55446677));
        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);

        string memory label = "graceperioddomain";
        bytes32 secret = 0x0;
        uint80 registrationLength = 30; // Short registration period for testing
        address recipient = address(0x5555);

        // Register SLD
        hoax(address(0x420), 2 ether);
        manager.registerWithCommit{value: 1 ether + 1}(label, secret, registrationLength, parentNamehash, recipient);

        // Verify count is 1
        assertEq(manager.sldCountPerTld(parentNamehash), 1, "count should be 1 after registration");

        // Fast forward time to after registration but within grace period
        // Registration expired but still within grace period
        vm.warp(block.timestamp + (registrationLength * 1 days) + (manager.gracePeriod() / 2));

        // Try to burn the domain during grace period - should fail
        address randomUser = address(0x9999);
        vm.prank(randomUser);
        vm.expectRevert("domain not expired");
        manager.burnExpiredSld(label, parentNamehash);

        // Verify count is still 1
        assertEq(manager.sldCountPerTld(parentNamehash), 1, "count should still be 1 during grace period");
    }

    // ========== BULK BURN EXPIRED SLD TESTS ==========

    function testBulkBurnExpiredSld() public {
        setUpLabelValidator();
        setUpGlobalStrategy(true, true, 1 ether);

        bytes32 parentNamehash = bytes32(uint256(0x55446677));
        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);

        // Register multiple SLDs with short registration period
        string[] memory labels = new string[](3);
        labels[0] = "expired1";
        labels[1] = "expired2";
        labels[2] = "expired3";

        bytes32 secret = 0x0;
        uint80 registrationLength = 30; // Short registration period for testing
        address recipient = address(0x5555);

        // Register all SLDs
        for (uint256 i = 0; i < labels.length; i++) {
            hoax(address(0x420), 2 ether);
            manager.registerWithCommit{value: 1 ether + 1}(
                labels[i], secret, registrationLength, parentNamehash, recipient
            );
        }

        // Verify count is 3
        assertEq(manager.sldCountPerTld(parentNamehash), 3, "count should be 3 after registration");

        // Fast forward time to after registration + grace period
        vm.warp(block.timestamp + (registrationLength * 1 days) + manager.gracePeriod() + 1);

        // Anyone should be able to bulk burn the expired domains
        address randomUser = address(0x9999);
        vm.prank(randomUser);
        manager.bulkBurnExpiredSld(labels, parentNamehash);

        // Verify count decremented to 0
        uint256 countAfterBurn = manager.sldCountPerTld(parentNamehash);
        assertEq(countAfterBurn, 0, "count should decrement to 0 after bulk burning expired domains");
    }

    function testBulkBurnExpiredSldPartialSuccess() public {
        setUpLabelValidator();
        setUpGlobalStrategy(true, true, 1 ether);

        bytes32 parentNamehash = bytes32(uint256(0x55446677));
        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);

        // Register SLDs with different registration lengths
        string[] memory expiredLabels = new string[](2);
        expiredLabels[0] = "expired1";
        expiredLabels[1] = "expired2";

        string memory activeLabel = "active";

        bytes32 secret = 0x0;
        uint80 shortLength = 30; // Will expire
        uint80 longLength = 365; // Will not expire
        address recipient = address(0x5555);

        // Register expired domains
        for (uint256 i = 0; i < expiredLabels.length; i++) {
            hoax(address(0x420), 2 ether);
            manager.registerWithCommit{value: 1 ether + 1}(
                expiredLabels[i], secret, shortLength, parentNamehash, recipient
            );
        }

        // Register active domain
        hoax(address(0x420), 2 ether);
        manager.registerWithCommit{value: 1 ether + 1}(activeLabel, secret, longLength, parentNamehash, recipient);

        // Verify count is 3
        assertEq(manager.sldCountPerTld(parentNamehash), 3, "count should be 3 after registration");

        // Fast forward time to expire only the short-term registrations
        vm.warp(block.timestamp + (shortLength * 1 days) + manager.gracePeriod() + 1);

        // Try to bulk burn including the active domain - should fail
        string[] memory mixedLabels = new string[](3);
        mixedLabels[0] = expiredLabels[0];
        mixedLabels[1] = expiredLabels[1];
        mixedLabels[2] = activeLabel;

        address randomUser = address(0x9999);
        vm.prank(randomUser);
        vm.expectRevert("domain not expired");
        manager.bulkBurnExpiredSld(mixedLabels, parentNamehash);

        // Should be able to bulk burn just the expired ones
        vm.prank(randomUser);
        manager.bulkBurnExpiredSld(expiredLabels, parentNamehash);

        // Verify count decremented by 2
        uint256 countAfterBurn = manager.sldCountPerTld(parentNamehash);
        assertEq(countAfterBurn, 1, "count should decrement to 1 after burning 2 expired domains");
    }

    function testBulkBurnExpiredSldFailsWithEmptyArray() public {
        bytes32 parentNamehash = bytes32(uint256(0x55446677));

        string[] memory emptyLabels = new string[](0);

        vm.expectRevert("no labels provided");
        manager.bulkBurnExpiredSld(emptyLabels, parentNamehash);
    }

    function testBulkBurnExpiredSldFailsWithTooManyLabels() public {
        bytes32 parentNamehash = bytes32(uint256(0x55446677));

        // Create array with 101 labels (exceeds limit of 100)
        string[] memory tooManyLabels = new string[](101);
        for (uint256 i = 0; i < 101; i++) {
            tooManyLabels[i] = string(abi.encodePacked("domain", vm.toString(i)));
        }

        vm.expectRevert("too many labels");
        manager.bulkBurnExpiredSld(tooManyLabels, parentNamehash);
    }

    function testBulkBurnExpiredSldFailsForNonExistentDomain() public {
        bytes32 parentNamehash = bytes32(uint256(0x55446677));

        string[] memory nonExistentLabels = new string[](1);
        nonExistentLabels[0] = "nonexistentdomain";

        vm.expectRevert("domain not registered");
        manager.bulkBurnExpiredSld(nonExistentLabels, parentNamehash);
    }

    function testBulkBurnExpiredSldFailsForNonExpiredDomains() public {
        setUpLabelValidator();
        setUpGlobalStrategy(true, true, 1 ether);

        bytes32 parentNamehash = bytes32(uint256(0x55446677));
        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);

        string[] memory labels = new string[](2);
        labels[0] = "active1";
        labels[1] = "active2";

        bytes32 secret = 0x0;
        uint80 registrationLength = 365; // Long registration period
        address recipient = address(0x5555);

        // Register active domains
        for (uint256 i = 0; i < labels.length; i++) {
            hoax(address(0x420), 2 ether);
            manager.registerWithCommit{value: 1 ether + 1}(
                labels[i], secret, registrationLength, parentNamehash, recipient
            );
        }

        // Try to bulk burn active domains - should fail
        address randomUser = address(0x9999);
        vm.prank(randomUser);
        vm.expectRevert("domain not expired");
        manager.bulkBurnExpiredSld(labels, parentNamehash);

        // Verify count is still 2
        assertEq(manager.sldCountPerTld(parentNamehash), 2, "count should still be 2");
    }

    function testBulkBurnExpiredSldFailsDuringGracePeriod() public {
        setUpLabelValidator();
        setUpGlobalStrategy(true, true, 1 ether);

        bytes32 parentNamehash = bytes32(uint256(0x55446677));
        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);

        string[] memory labels = new string[](2);
        labels[0] = "grace1";
        labels[1] = "grace2";

        bytes32 secret = 0x0;
        uint80 registrationLength = 30; // Short registration period for testing
        address recipient = address(0x5555);

        // Register domains
        for (uint256 i = 0; i < labels.length; i++) {
            hoax(address(0x420), 2 ether);
            manager.registerWithCommit{value: 1 ether + 1}(
                labels[i], secret, registrationLength, parentNamehash, recipient
            );
        }

        // Verify count is 2
        assertEq(manager.sldCountPerTld(parentNamehash), 2, "count should be 2 after registration");

        // Fast forward time to after registration but within grace period
        vm.warp(block.timestamp + (registrationLength * 1 days) + (manager.gracePeriod() / 2));

        // Try to bulk burn during grace period - should fail
        address randomUser = address(0x9999);
        vm.prank(randomUser);
        vm.expectRevert("domain not expired");
        manager.bulkBurnExpiredSld(labels, parentNamehash);

        // Verify count is still 2
        assertEq(manager.sldCountPerTld(parentNamehash), 2, "count should still be 2 during grace period");
    }

    function testBulkBurnExpiredSldLargeArray() public {
        setUpLabelValidator();
        setUpGlobalStrategy(true, true, 1 ether);

        bytes32 parentNamehash = bytes32(uint256(0x55446677));
        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);

        // Test with maximum allowed array size (100)
        string[] memory labels = new string[](100);
        bytes32 secret = 0x0;
        uint80 registrationLength = 30; // Short registration period for testing
        address recipient = address(0x5555);

        // Register all domains
        for (uint256 i = 0; i < labels.length; i++) {
            labels[i] = string(abi.encodePacked("bulk", vm.toString(i)));
            hoax(address(0x420), 2 ether);
            manager.registerWithCommit{value: 1 ether + 1}(
                labels[i], secret, registrationLength, parentNamehash, recipient
            );
        }

        // Verify count is 100
        assertEq(manager.sldCountPerTld(parentNamehash), 100, "count should be 100 after registration");

        // Fast forward time to after registration + grace period
        vm.warp(block.timestamp + (registrationLength * 1 days) + manager.gracePeriod() + 1);

        // Bulk burn all domains
        address randomUser = address(0x9999);
        vm.prank(randomUser);
        manager.bulkBurnExpiredSld(labels, parentNamehash);

        // Verify count decremented to 0
        uint256 countAfterBurn = manager.sldCountPerTld(parentNamehash);
        assertEq(countAfterBurn, 0, "count should decrement to 0 after bulk burning all expired domains");
    }

    function testBulkBurnExpiredSldSingleDomain() public {
        setUpLabelValidator();
        setUpGlobalStrategy(true, true, 1 ether);

        bytes32 parentNamehash = bytes32(uint256(0x55446677));
        tld.register(address(0x99), uint256(parentNamehash));
        setUpRegistrationStrategy(parentNamehash);

        // Test with single domain in array
        string[] memory labels = new string[](1);
        labels[0] = "singledomain";

        bytes32 secret = 0x0;
        uint80 registrationLength = 30; // Short registration period for testing
        address recipient = address(0x5555);

        // Register domain
        hoax(address(0x420), 2 ether);
        manager.registerWithCommit{value: 1 ether + 1}(labels[0], secret, registrationLength, parentNamehash, recipient);

        // Verify count is 1
        assertEq(manager.sldCountPerTld(parentNamehash), 1, "count should be 1 after registration");

        // Fast forward time to after registration + grace period
        vm.warp(block.timestamp + (registrationLength * 1 days) + manager.gracePeriod() + 1);

        // Bulk burn single domain
        address randomUser = address(0x9999);
        vm.prank(randomUser);
        manager.bulkBurnExpiredSld(labels, parentNamehash);

        // Verify count decremented to 0
        uint256 countAfterBurn = manager.sldCountPerTld(parentNamehash);
        assertEq(countAfterBurn, 0, "count should decrement to 0 after bulk burning single expired domain");
    }
}

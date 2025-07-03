// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./SldRegistrationManagerBase.t.sol";

contract TestSldCountFix is SldRegistrationManagerBase {
    /**
     * @notice Test that SLD count doesn't increment when re-registering an expired domain
     */
    function testSldCountDoesNotIncrementOnExpiredDomainReRegistration() public {
        // Register initial domain
        string memory label = "testdomain";
        bytes32 parentNamehash = parentTldNamehash;
        bytes32 sldNamehash = Namehash.getNamehash(parentNamehash, label);

        // Initial registration
        vm.deal(user, 1 ether);
        vm.prank(user);
        manager.registerWithCommit{value: 1 ether}(
            label,
            secret,
            365, // 1 year
            parentNamehash,
            user
        );

        // Check initial count
        uint256 initialCount = manager.sldCountPerTld(parentNamehash);
        assertEq(initialCount, 1, "Initial count should be 1");

        // Fast forward past expiry + grace period
        vm.warp(block.timestamp + 365 days + 31 days);

        // Verify domain has expired by checking registration history
        (uint72 regTime, uint80 regLength, ) = manager.sldRegistrationHistory(sldNamehash);
        assertTrue(regTime + regLength + 30 days < block.timestamp, "Domain should have expired");

        // Re-register the same domain by a different user
        address newUser = address(0x456);
        vm.deal(newUser, 1 ether);
        vm.prank(newUser);
        manager.registerWithCommit{value: 1 ether}(
            label,
            secret,
            365, // 1 year
            parentNamehash,
            newUser
        );

        // Check count after re-registration - should still be 1, not 2
        uint256 finalCount = manager.sldCountPerTld(parentNamehash);
        assertEq(finalCount, 1, "Count should remain 1 after re-registration of expired domain");

        // Verify the new owner is correct
        assertEq(sld.ownerOf(uint256(sldNamehash)), newUser, "New user should own the domain");
    }

    /**
     * @notice Test that SLD count increments correctly for truly new domains
     */
    function testSldCountIncrementsForNewDomains() public {
        string memory label1 = "domain1";
        string memory label2 = "domain2";
        bytes32 parentNamehash = parentTldNamehash;

        // Register first domain
        vm.deal(user, 1 ether);
        vm.prank(user);
        manager.registerWithCommit{value: 1 ether}(label1, secret, 365, parentNamehash, user);

        uint256 countAfterFirst = manager.sldCountPerTld(parentNamehash);
        assertEq(countAfterFirst, 1, "Count should be 1 after first registration");

        // Register second domain (different label)
        vm.deal(user, 1 ether);
        vm.prank(user);
        manager.registerWithCommit{value: 1 ether}(label2, secret, 365, parentNamehash, user);

        uint256 countAfterSecond = manager.sldCountPerTld(parentNamehash);
        assertEq(countAfterSecond, 2, "Count should be 2 after second registration");
    }

    /**
     * @notice Test mixed scenario: new domain + expired domain re-registration
     */
    function testMixedScenario() public {
        string memory label1 = "original";
        string memory label2 = "newdomain";
        bytes32 parentNamehash = parentTldNamehash;

        // Register first domain
        vm.deal(user, 1 ether);
        vm.prank(user);
        manager.registerWithCommit{value: 1 ether}(label1, secret, 365, parentNamehash, user);

        assertEq(manager.sldCountPerTld(parentNamehash), 1, "Count should be 1");

        // Fast forward past expiry + grace period for first domain
        vm.warp(block.timestamp + 365 days + 31 days);

        // Register a completely new domain
        vm.deal(user, 1 ether);
        vm.prank(user);
        manager.registerWithCommit{value: 1 ether}(label2, secret, 365, parentNamehash, user);

        assertEq(manager.sldCountPerTld(parentNamehash), 2, "Count should be 2 after new domain");

        // Re-register the expired domain
        address newUser = address(0x789);
        vm.deal(newUser, 1 ether);
        vm.prank(newUser);
        manager.registerWithCommit{value: 1 ether}(label1, secret, 365, parentNamehash, newUser);

        // Count should still be 2 (not 3) because label1 was a re-registration
        assertEq(
            manager.sldCountPerTld(parentNamehash),
            2,
            "Count should remain 2 after re-registration"
        );
    }
}

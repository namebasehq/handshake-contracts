// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

import "interfaces/ITldClaimManager.sol";
import "contracts/TldClaimManager.sol";
import "contracts/HandshakeTld.sol";

contract TestTldClaimManager is Test {
    ITldClaimManager internal manager;
    HandshakeTld internal nft;

    function setUp() public {
        manager = new TldClaimManager();
        nft = new HandshakeTld(manager);
        //nft.setTldClaimManager(manager);
    }

    function testAddTldManagerWallet() public {
        address allowed_address = address(0x134567);
        manager.updateAllowedTldManager(allowed_address, true);

        assertTrue(manager.AllowedTldManager(allowed_address));
    }

    function testAddTldManagerWalletFromNotContractOwner() public {
        address allowed_address = address(0x134567);

        vm.startPrank(address(0x12345678));
        vm.expectRevert("Ownable: caller is not the owner");
        manager.updateAllowedTldManager(allowed_address, true);
        vm.stopPrank();
    }

    function testAddWalletAndClaimTld() public {
        address allowed_address = address(0x134567);
        manager.updateAllowedTldManager(allowed_address, true);

        string[] memory domains = new string[](1);
        address[] memory addresses = new address[](1);
        domains[0] = "badass";
        addresses[0] = allowed_address;
        vm.startPrank(allowed_address);
        manager.addTldAndClaimant(addresses, domains);
        manager.canClaim(allowed_address, "badass");
        vm.stopPrank();
    }

    function testAddWalletAndClaimTldDuplicateClaim() public {
        address allowed_address = address(0x134567);
        manager.updateAllowedTldManager(allowed_address, true);
        manager.setHandshakeTldContract(nft);
        string[] memory domains = new string[](1);
        address[] memory addresses = new address[](1);
        domains[0] = "badass";
        addresses[0] = allowed_address;
        vm.startPrank(allowed_address);
        manager.addTldAndClaimant(addresses, domains);
        manager.claimTld("badass");
        vm.expectRevert("not eligible to claim");
        manager.claimTld("badass");
        vm.stopPrank();
    }

    function testAddWalletAndClaimIncorrectTld() public {
        address allowed_address = address(0x134567);
        manager.updateAllowedTldManager(allowed_address, true);

        string[] memory domains = new string[](2);
        address[] memory addresses = new address[](2);
        domains[0] = "badass";
        domains[1] = "notbadass";
        addresses[0] = allowed_address;
        addresses[1] = address(0x1234);
        vm.startPrank(allowed_address);
        manager.addTldAndClaimant(addresses, domains);
        assertFalse(manager.canClaim(allowed_address, "notbadass"));
        vm.expectRevert("not eligible to claim");
        manager.claimTld("notbadass");
        vm.stopPrank();
    }

    function testAddWalletAndClaimTldWithDifferentWallet() public {
        address allowed_address = address(0x134567);
        address other_address = address(0x131313);
        manager.updateAllowedTldManager(allowed_address, true);

        string[] memory domains = new string[](2);
        address[] memory addresses = new address[](2);
        domains[0] = "badass";
        domains[1] = "notbadass";
        addresses[0] = allowed_address;
        addresses[1] = other_address;
        vm.startPrank(allowed_address);
        manager.addTldAndClaimant(addresses, domains);
        vm.stopPrank();
        vm.startPrank(address(0x131313)); //wallet should only be allowed to claim "notbadass"
        assertFalse(manager.canClaim(other_address, "badass"));
        vm.expectRevert("not eligible to claim");
        manager.claimTld("badass");
        vm.stopPrank();
    }

    function testAddTldWithDeactivatedTldAllowedWallet() public {
        address allowed_address = address(0x134567);
        manager.updateAllowedTldManager(allowed_address, true);
        manager.updateAllowedTldManager(allowed_address, false);
        string[] memory domains = new string[](1);
        address[] memory addresses = new address[](1);
        domains[0] = "badass";
        addresses[0] = allowed_address;
        vm.startPrank(allowed_address);
        vm.expectRevert("not authorised to add TLD");
        manager.addTldAndClaimant(addresses, domains);
        vm.stopPrank();
    }

    function testAddTldClaimantAndDomainsIncorrectlySizedLists() public {
        address allowed_address = address(0x134567);
        manager.updateAllowedTldManager(allowed_address, true);
        string[] memory domains = new string[](1);
        address[] memory addresses = new address[](2);
        domains[0] = "badass";
        addresses[0] = allowed_address;
        addresses[1] = address(0x99);
        vm.startPrank(allowed_address);
        vm.expectRevert("address and domain list should be the same length");
        manager.addTldAndClaimant(addresses, domains);
        vm.stopPrank();
    }
}

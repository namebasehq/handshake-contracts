// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

import "interfaces/ITldClaimManager.sol";
import "contracts/TldClaimManager.sol";
import "contracts/HandshakeTld.sol";
import "test/mocks/MockLabelValidator.sol";
import "test/mocks/MockUsdOracle.sol";
import "interfaces/ILabelValidator.sol";
import "test/mocks/MockMetadataService.sol";
import "mocks/MockHandshakeSld.sol";
import "utils/Namehash.sol";

contract TestTldClaimManager is Test {
    TldClaimManager internal manager;
    HandshakeTld internal nft;
    IHandshakeSld internal sld;
    IResolver internal resolver;
    ILabelValidator internal labelValidator;
    MockMetadataService internal metadata;
    ISldRegistrationStrategy internal strategy;

    function setUp() public {
        metadata = new MockMetadataService("base_url");
        labelValidator = new MockLabelValidator(true);
        manager = new TldClaimManager();
        sld = new MockHandshakeSld();
        nft = new HandshakeTld(manager);
        nft.setMetadataContract(metadata);
        MockUsdOracle oracle = new MockUsdOracle(200000000000); // $2000
        manager.init(labelValidator, address(this), nft, strategy, oracle, 0, address(0));
    }

    function testAddTldManagerWallet() public {
        address allowed_address = address(0x134567);
        manager.updateAllowedTldManager(allowed_address, true);

        assertTrue(manager.allowedTldManager(allowed_address));
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
        manager.claimTld("badass", allowed_address);
        assertEq(nft.ownerOf(uint256(Namehash.getTldNamehash(domains[0]))), allowed_address);
        vm.expectRevert("not eligible to claim");
        manager.claimTld("badass", allowed_address);
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
        manager.claimTld("notbadass", msg.sender);
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
        manager.claimTld("badass", msg.sender);
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

    function testUpdateMintPriceFromOwner_pass() public {
        manager.updateMintPrice(1000000000000000000);

        assertEq(manager.mintPriceInDollars(), 1000000000000000000);
    }

    function testUpdateMintPriceFromNotOwner_fail() public {
        vm.startPrank(address(0x112233));
        vm.expectRevert("Ownable: caller is not the owner");
        manager.updateMintPrice(1000000000000000000);
    }

    function testMintTldWithNoneZeroPriceExactFunds() public {
        uint256 price = 2000 ether; // 2000 USD
        manager.updateMintPrice(price);
        address allowed_address = address(0x134567);
        manager.updateAllowedTldManager(allowed_address, true);
        manager.setHandshakeTldContract(nft);
        string[] memory domains = new string[](1);
        address[] memory addresses = new address[](1);
        domains[0] = "badass";
        addresses[0] = allowed_address;
        startHoax(allowed_address, price);
        manager.addTldAndClaimant(addresses, domains);
        manager.claimTld{value: 1 ether}("badass", allowed_address);
        assertEq(nft.ownerOf(uint256(Namehash.getTldNamehash(domains[0]))), allowed_address);
    }

    function testMintTldWithNoneZeroPriceNotEnoughFunds_fail() public {
        uint256 price = 2000 ether; // 2000 USD
        manager.updateMintPrice(price);
        address allowed_address = address(0x134567);
        manager.updateAllowedTldManager(allowed_address, true);
        manager.setHandshakeTldContract(nft);
        string[] memory domains = new string[](1);
        address[] memory addresses = new address[](1);
        domains[0] = "badass";
        addresses[0] = allowed_address;
        startHoax(allowed_address, price);
        manager.addTldAndClaimant(addresses, domains);
        vm.expectRevert("not enough ether");
        manager.claimTld{value: 1 ether - 1}("badass", allowed_address);
    }

    function testMintTldWithNoneZeroPriceOverpay_expect_refund() public {
        uint256 price = 2000 ether; // 2000 USD
        manager.updateMintPrice(price);

        address allowed_address = address(0x134567);
        manager.updateAllowedTldManager(allowed_address, true);
        manager.setHandshakeTldContract(nft);
        string[] memory domains = new string[](1);
        address[] memory addresses = new address[](1);
        domains[0] = "badass";
        addresses[0] = allowed_address;
        startHoax(allowed_address, 3 ether);
        manager.addTldAndClaimant(addresses, domains);
        // $2000 is 1 ether, so we should get 2 ether back
        manager.claimTld{value: 3 ether}("badass", allowed_address);
        assertEq(nft.ownerOf(uint256(Namehash.getTldNamehash(domains[0]))), allowed_address);

        assertEq(allowed_address.balance, 2 ether);
        assertEq(manager.handshakeWalletPayoutAddress().balance, 1 ether);
    }


}

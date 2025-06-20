// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

import "interfaces/ITldClaimManager.sol";
import "contracts/TldClaimManager.sol";
import "contracts/HandshakeTld.sol";
import "test/mocks/MockLabelValidator.sol";
import "test/mocks/MockUsdOracle.sol";
import "test/mocks/TestingTldClaimManager.sol";
import "interfaces/ILabelValidator.sol";
import "test/mocks/MockMetadataService.sol";
import "mocks/MockHandshakeSld.sol";
import "mocks/MockSldRegistrationManager.sol";
import "utils/Namehash.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/**
 * @title TestTldBurning
 * @dev Test contract specifically for testing the TLD burning functionality
 */
contract TestTldBurning is Test {
    using stdStorage for StdStorage;

    TldClaimManager internal manager;
    HandshakeTld internal nft;
    IHandshakeSld internal sld;
    ILabelValidator internal labelValidator;
    MockMetadataService internal metadata;
    ISldRegistrationStrategy internal strategy;
    MockSldRegistrationManager internal mockSldRegistrationManager;

    // Test signer private key and address
    uint256 internal signerPrivateKey = 0x1234567890123456789012345678901234567890123456789012345678901234;
    address internal signerAddress;

    event TldBurned(address indexed _owner, uint256 indexed _id, string _label);

    function setUp() public {
        signerAddress = vm.addr(signerPrivateKey);

        metadata = new MockMetadataService("base_url");
        labelValidator = new MockLabelValidator(true);
        TestingTldClaimManager implementation = new TestingTldClaimManager();
        TransparentUpgradeableProxy uups =
            new TransparentUpgradeableProxy(address(implementation), address(0x224455), bytes(""));

        manager = TldClaimManager(address(uups));

        sld = new MockHandshakeSld();
        nft = new HandshakeTld();
        nft.setTldClaimManager(manager);
        nft.setMetadataContract(metadata);
        MockUsdOracle oracle = new MockUsdOracle(200000000000); // $2000

        mockSldRegistrationManager = new MockSldRegistrationManager(nft, IGlobalRegistrationRules(address(0)));

        manager.init(labelValidator, address(this), nft, strategy, oracle, 0, address(0));

        // Add the test signer as a valid signer
        manager.updateSigner(signerAddress, true);
    }

    function generateSignature(address burner, bytes32 tldNamehash) internal returns (uint8 v, bytes32 r, bytes32 s) {
        bytes32 hash = manager.getBurnHash(burner, tldNamehash);
        (v, r, s) = vm.sign(signerPrivateKey, hash);
    }

    function testBurnTld() public {
        string memory tldLabel = "test";
        bytes32 tldNamehash = Namehash.getTldNamehash(tldLabel);

        // Setup: Add TLD and claimant
        address[] memory addrs = new address[](1);
        string[] memory domains = new string[](1);
        addrs[0] = address(this);
        domains[0] = tldLabel;

        manager.updateAllowedTldManager(address(this), true);
        manager.addTldAndClaimant(addrs, domains);

        // Claim the TLD
        manager.claimTld(tldLabel, address(this));

        // Set the SLD registration manager
        manager.setSldRegistrationManager(ISldRegistrationManager(address(mockSldRegistrationManager)));

        // Mock the SLD count to be 0 (no SLDs)
        mockSldRegistrationManager.setSldCount(tldNamehash, 0);

        // Generate signature
        (uint8 v, bytes32 r, bytes32 s) = generateSignature(address(this), tldNamehash);

        // Burn the TLD
        vm.expectEmit(true, true, true, true);
        emit TldBurned(address(this), uint256(tldNamehash), tldLabel);
        manager.burnTld(tldLabel, v, r, s);

        // Verify the TLD is burned
        vm.expectRevert("ERC721: invalid token ID");
        nft.ownerOf(uint256(tldNamehash));
    }

    function testCannotBurnTldWithSlds() public {
        string memory tldLabel = "test";
        bytes32 tldNamehash = Namehash.getTldNamehash(tldLabel);

        // Setup: Add TLD and claimant
        address[] memory addrs = new address[](1);
        string[] memory domains = new string[](1);
        addrs[0] = address(this);
        domains[0] = tldLabel;

        manager.updateAllowedTldManager(address(this), true);
        manager.addTldAndClaimant(addrs, domains);

        // Claim the TLD
        manager.claimTld(tldLabel, address(this));

        // Set the SLD registration manager
        manager.setSldRegistrationManager(ISldRegistrationManager(address(mockSldRegistrationManager)));

        // Mock the SLD count to be > 0 (has SLDs)
        mockSldRegistrationManager.setSldCount(tldNamehash, 1);

        // Generate signature
        (uint8 v, bytes32 r, bytes32 s) = generateSignature(address(this), tldNamehash);

        // Try to burn the TLD, should fail
        vm.expectRevert("SLDs exist for this TLD");
        manager.burnTld(tldLabel, v, r, s);
    }

    function testCannotBurnTldIfNotOwner() public {
        string memory tldLabel = "test";
        bytes32 tldNamehash = Namehash.getTldNamehash(tldLabel);

        // Setup: Add TLD and claimant
        address[] memory addrs = new address[](1);
        string[] memory domains = new string[](1);
        addrs[0] = address(this);
        domains[0] = tldLabel;

        manager.updateAllowedTldManager(address(this), true);
        manager.addTldAndClaimant(addrs, domains);

        // Claim the TLD
        manager.claimTld(tldLabel, address(this));

        // Set the SLD registration manager
        manager.setSldRegistrationManager(ISldRegistrationManager(address(mockSldRegistrationManager)));

        // Mock the SLD count to be 0 (no SLDs)
        mockSldRegistrationManager.setSldCount(tldNamehash, 0);

        // Generate signature for a different address
        (uint8 v, bytes32 r, bytes32 s) = generateSignature(address(0x123), tldNamehash);

        // Try to burn the TLD as another address, should fail
        vm.prank(address(0x123));
        vm.expectRevert("not TLD owner");
        manager.burnTld(tldLabel, v, r, s);
    }

    function testCannotBurnTldWithoutSettingSldRegistrationManager() public {
        string memory tldLabel = "test";
        bytes32 tldNamehash = Namehash.getTldNamehash(tldLabel);

        // Setup: Add TLD and claimant
        address[] memory addrs = new address[](1);
        string[] memory domains = new string[](1);
        addrs[0] = address(this);
        domains[0] = tldLabel;

        manager.updateAllowedTldManager(address(this), true);
        manager.addTldAndClaimant(addrs, domains);

        // Claim the TLD
        manager.claimTld(tldLabel, address(this));

        // Generate signature
        (uint8 v, bytes32 r, bytes32 s) = generateSignature(address(this), tldNamehash);

        // Try to burn the TLD without setting SLD registration manager, should fail
        vm.expectRevert("SLD registration manager not set");
        manager.burnTld(tldLabel, v, r, s);
    }

    function testCannotBurnTldWithInvalidSignature() public {
        string memory tldLabel = "test";
        bytes32 tldNamehash = Namehash.getTldNamehash(tldLabel);

        // Setup: Add TLD and claimant
        address[] memory addrs = new address[](1);
        string[] memory domains = new string[](1);
        addrs[0] = address(this);
        domains[0] = tldLabel;

        manager.updateAllowedTldManager(address(this), true);
        manager.addTldAndClaimant(addrs, domains);

        // Claim the TLD
        manager.claimTld(tldLabel, address(this));

        // Set the SLD registration manager
        manager.setSldRegistrationManager(ISldRegistrationManager(address(mockSldRegistrationManager)));

        // Mock the SLD count to be 0 (no SLDs)
        mockSldRegistrationManager.setSldCount(tldNamehash, 0);

        // Use invalid signature values
        uint8 v = 27;
        bytes32 r = bytes32(uint256(1));
        bytes32 s = bytes32(uint256(2));

        // Try to burn the TLD with invalid signature, should fail
        vm.expectRevert("invalid signature");
        manager.burnTld(tldLabel, v, r, s);
    }

    function testCannotRemintTldAfterBurning() public {
        string memory tldLabel = "test";
        bytes32 tldNamehash = Namehash.getTldNamehash(tldLabel);

        // Step 1: Contract owner adds reservation for TLD to mint
        address[] memory addrs = new address[](1);
        string[] memory domains = new string[](1);
        addrs[0] = address(this);
        domains[0] = tldLabel;

        manager.updateAllowedTldManager(address(this), true);
        manager.addTldAndClaimant(addrs, domains);

        // Step 2: TLD owner mints TLD
        manager.claimTld(tldLabel, address(this));

        // Verify TLD is minted and owned
        assertEq(nft.ownerOf(uint256(tldNamehash)), address(this));

        // Step 3: User burns TLD
        manager.setSldRegistrationManager(ISldRegistrationManager(address(mockSldRegistrationManager)));
        mockSldRegistrationManager.setSldCount(tldNamehash, 0);

        (uint8 v, bytes32 r, bytes32 s) = generateSignature(address(this), tldNamehash);
        manager.burnTld(tldLabel, v, r, s);

        // Verify the TLD is burned
        vm.expectRevert("ERC721: invalid token ID");
        nft.ownerOf(uint256(tldNamehash));

        // Step 4: TLD owner tries to remint TLD, this should fail
        // The claimant mapping should have been deleted during the original claim
        vm.expectRevert("not eligible to claim");
        manager.claimTld(tldLabel, address(this));
    }
}

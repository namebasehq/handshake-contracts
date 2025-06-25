// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "test/mocks/TestingTldClaimManager.sol";
import "src/contracts/TldClaimManager.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "test/mocks/MockHandshakeTld.sol";
import "test/mocks/MockSldRegistrationManager.sol";
import "test/mocks/MockLabelValidator.sol";
import "test/mocks/MockUsdOracle.sol";
import "test/mocks/MockRegistrationStrategy.sol";
import "interfaces/IGlobalRegistrationRules.sol";
import "interfaces/IHandshakeTld.sol";
import "interfaces/ITldClaimManager.sol";
import {Namehash} from "utils/Namehash.sol";

contract TestTldBurningExpiry is Test {
    TldClaimManager public tldClaimManager;
    MockHandshakeTld public tldNft;
    MockSldRegistrationManager public sldRegistrationManager;
    MockLabelValidator public validator;
    MockUsdOracle public oracle;
    MockRegistrationStrategy public strategy;

    address public owner = address(0x1);
    address public tldOwner = address(0x2);
    address public authorizedSigner = address(0x3);
    uint256 public signerPrivateKey = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;

    string public constant DOMAIN = "test";
    bytes32 public tldNamehash;
    uint256 public tokenId;

    event TldBurned(address indexed _owner, uint256 indexed _id, string _label);

    function setUp() public {
        // Deploy mocks
        tldNft = new MockHandshakeTld();
        sldRegistrationManager =
            new MockSldRegistrationManager(IHandshakeTld(address(tldNft)), IGlobalRegistrationRules(address(0)));
        validator = new MockLabelValidator(true);
        oracle = new MockUsdOracle(200000000000); // $2000
        strategy = new MockRegistrationStrategy(100); // $100

        // Set up domain and token
        tldNamehash = Namehash.getTldNamehash(DOMAIN);
        tokenId = uint256(tldNamehash);
    }

    function deployAndInitialize() internal {
        // Deploy TLD claim manager with proxy pattern
        TestingTldClaimManager implementation = new TestingTldClaimManager();
        TransparentUpgradeableProxy proxy =
            new TransparentUpgradeableProxy(address(implementation), address(0x224455), bytes(""));
        tldClaimManager = TldClaimManager(address(proxy));

        // Initialize the contract
        tldClaimManager.init(validator, owner, IHandshakeTld(address(tldNft)), strategy, oracle, 0, owner);

        // Configure the contract as owner
        vm.startPrank(owner);
        tldClaimManager.initializeDomainSeparator();
        tldClaimManager.setSldRegistrationManager(sldRegistrationManager);
        tldClaimManager.updateSigner(vm.addr(signerPrivateKey), true);
        vm.stopPrank();

        // Set the TLD claim manager on the NFT contract
        tldNft.setTldClaimManager(ITldClaimManager(address(tldClaimManager)));

        // Set up TLD ownership by registering to the owner
        tldNft.register(tldOwner, tokenId);

        // Ensure no SLDs exist for this TLD
        sldRegistrationManager.setSldCount(tldNamehash, 0);
    }

    function testBurnTldWithValidExpiry() public {
        deployAndInitialize();
        uint256 expiry = block.timestamp + 1 hours;

        // Generate valid signature with expiry
        bytes32 messageToSign = tldClaimManager.getBurnHash(tldOwner, tldNamehash, expiry);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, messageToSign);

        // Expect the burn event
        vm.expectEmit(true, true, false, true);
        emit TldBurned(tldOwner, tokenId, DOMAIN);

        // Burn the TLD
        vm.prank(tldOwner);
        tldClaimManager.burnTld(DOMAIN, expiry, v, r, s);

        // Verify the TLD was burned (should revert when trying to get owner)
        vm.expectRevert("ERC721: invalid token ID");
        tldNft.ownerOf(tokenId);
    }

    function testBurnTldWithExactExpiryTime() public {
        deployAndInitialize();
        uint256 expiry = block.timestamp;

        // Generate valid signature with expiry at exact current time
        bytes32 messageToSign = tldClaimManager.getBurnHash(tldOwner, tldNamehash, expiry);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, messageToSign);

        // Should succeed since block.timestamp <= expiry
        vm.prank(tldOwner);
        tldClaimManager.burnTld(DOMAIN, expiry, v, r, s);

        // Verify the TLD was burned (should revert when trying to get owner)
        vm.expectRevert("ERC721: invalid token ID");
        tldNft.ownerOf(tokenId);
    }

    function testCannotBurnTldWithExpiredSignature() public {
        deployAndInitialize();
        uint256 expiry = block.timestamp - 1; // Expired 1 second ago

        // Generate signature with expired timestamp
        bytes32 messageToSign = tldClaimManager.getBurnHash(tldOwner, tldNamehash, expiry);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, messageToSign);

        // Should fail due to expiry
        vm.expectRevert("signature expired");
        vm.prank(tldOwner);
        tldClaimManager.burnTld(DOMAIN, expiry, v, r, s);
    }

    function testCannotBurnTldWithExpiredSignatureAfterTimeAdvance() public {
        deployAndInitialize();
        uint256 expiry = block.timestamp + 1 hours;

        // Generate valid signature
        bytes32 messageToSign = tldClaimManager.getBurnHash(tldOwner, tldNamehash, expiry);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, messageToSign);

        // Advance time beyond expiry
        vm.warp(expiry + 1);

        // Should fail due to expiry
        vm.expectRevert("signature expired");
        vm.prank(tldOwner);
        tldClaimManager.burnTld(DOMAIN, expiry, v, r, s);
    }

    function testCannotBurnTldWithWrongExpiryInSignature() public {
        deployAndInitialize();
        uint256 actualExpiry = block.timestamp + 1 hours;
        uint256 wrongExpiry = block.timestamp + 2 hours;

        // Generate signature with one expiry
        bytes32 messageToSign = tldClaimManager.getBurnHash(tldOwner, tldNamehash, actualExpiry);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, messageToSign);

        // Try to use signature with different expiry parameter
        vm.expectRevert("invalid signature");
        vm.prank(tldOwner);
        tldClaimManager.burnTld(DOMAIN, wrongExpiry, v, r, s);
    }

    function testBurnTldWithFarFutureExpiry() public {
        deployAndInitialize();
        uint256 expiry = block.timestamp + 365 days; // 1 year from now

        // Generate valid signature with far future expiry
        bytes32 messageToSign = tldClaimManager.getBurnHash(tldOwner, tldNamehash, expiry);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, messageToSign);

        // Should succeed
        vm.prank(tldOwner);
        tldClaimManager.burnTld(DOMAIN, expiry, v, r, s);

        // Verify the TLD was burned (should revert when trying to get owner)
        vm.expectRevert("ERC721: invalid token ID");
        tldNft.ownerOf(tokenId);
    }

    function testGetBurnHashWithExpiry() public {
        deployAndInitialize();
        uint256 expiry = block.timestamp + 1 hours;

        // Test that getBurnHash returns consistent results
        bytes32 hash1 = tldClaimManager.getBurnHash(tldOwner, tldNamehash, expiry);
        bytes32 hash2 = tldClaimManager.getBurnHash(tldOwner, tldNamehash, expiry);

        assertEq(hash1, hash2, "Hash should be consistent for same inputs");

        // Test that different expiry gives different hash
        bytes32 hash3 = tldClaimManager.getBurnHash(tldOwner, tldNamehash, expiry + 1);
        assertTrue(hash1 != hash3, "Different expiry should give different hash");
    }

    function testCheckSignatureValidWithExpiry() public {
        deployAndInitialize();
        uint256 expiry = block.timestamp + 1 hours;

        // Generate valid signature
        bytes32 messageToSign = tldClaimManager.getBurnHash(tldOwner, tldNamehash, expiry);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, messageToSign);

        // Should return the correct signer
        address recoveredSigner = tldClaimManager.checkSignatureValid(tldOwner, tldNamehash, expiry, v, r, s);
        assertEq(recoveredSigner, vm.addr(signerPrivateKey), "Should recover correct signer");
    }

    function testCheckSignatureValidWithExpiredSignature() public {
        deployAndInitialize();
        uint256 expiry = block.timestamp - 1; // Expired

        // Generate signature (would be valid if not expired)
        bytes32 messageToSign = tldClaimManager.getBurnHash(tldOwner, tldNamehash, expiry);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, messageToSign);

        // Should fail due to expiry
        vm.expectRevert("signature expired");
        tldClaimManager.checkSignatureValid(tldOwner, tldNamehash, expiry, v, r, s);
    }

    function testMultipleBurnAttemptsWithSameSignature() public {
        deployAndInitialize();
        uint256 expiry = block.timestamp + 1 hours;

        // Generate valid signature
        bytes32 messageToSign = tldClaimManager.getBurnHash(tldOwner, tldNamehash, expiry);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, messageToSign);

        // First burn should succeed
        vm.prank(tldOwner);
        tldClaimManager.burnTld(DOMAIN, expiry, v, r, s);

        // Set up another TLD with same name (simulating re-registration)
        tldNft.register(tldOwner, tokenId);

        // Second burn with same signature should succeed since it's the same TLD and same signature
        // The signature is still valid for this TLD with this expiry
        vm.prank(tldOwner);
        tldClaimManager.burnTld(DOMAIN, expiry, v, r, s);

        // Verify the TLD was burned again
        vm.expectRevert("ERC721: invalid token ID");
        tldNft.ownerOf(tokenId);
    }

    function testExpiryBoundaryConditions() public {
        deployAndInitialize();
        // Test expiry at uint256 max
        uint256 maxExpiry = type(uint256).max;

        bytes32 messageToSign = tldClaimManager.getBurnHash(tldOwner, tldNamehash, maxExpiry);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, messageToSign);

        // Should succeed
        vm.prank(tldOwner);
        tldClaimManager.burnTld(DOMAIN, maxExpiry, v, r, s);

        // Verify the TLD was burned (should revert when trying to get owner)
        vm.expectRevert("ERC721: invalid token ID");
        tldNft.ownerOf(tokenId);
    }

    function testExpiryWithZeroValue() public {
        deployAndInitialize();
        uint256 expiry = 0;

        // This should fail since block.timestamp is definitely > 0
        bytes32 messageToSign = tldClaimManager.getBurnHash(tldOwner, tldNamehash, expiry);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, messageToSign);

        vm.expectRevert("signature expired");
        vm.prank(tldOwner);
        tldClaimManager.burnTld(DOMAIN, expiry, v, r, s);
    }
}

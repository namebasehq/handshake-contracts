// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "src/contracts/TldClaimManager.sol";
import {Namehash} from "utils/Namehash.sol";

contract TestSignatureDebug is Test {
    TldClaimManager public tldClaimManager;

    // From your logs
    address constant BURNER = 0x175F303781Efe881Ce40A511517186DbF364b3a7;
    address constant SIGNER_PUBLIC = 0x0A93DE7D66D09AB61b7e95077A260ee839B69f23;
    bytes32 constant TLD_NAMEHASH =
        0x4e40f6e0b682912885261b48c6a9ba4f76aac8f74cb47354d0508b49a6c988d8;
    string constant DOMAIN = "test2";

    // From your signature
    uint8 constant V = 28;
    bytes32 constant R = 0xfa761d5660716eafa5080995440a52508921e5ae9601bd577069a0b99fabb33b;
    bytes32 constant S = 0x39bcad1692dbb210a13a1508d0a42cf8e310c496d18f3c61a81c25d442dbba11;

    // Expected values from your logs
    bytes32 constant EXPECTED_DOMAIN_SEPARATOR =
        0x901e84d886f1a997683aa622e6d911b697d101793f446ecd9c3990932d5348ca;
    bytes32 constant EXPECTED_MESSAGE_HASH =
        0x071854eb9658265f15fd19539e496c96b2bf17b83497befe2b68b027236b7334;
    bytes32 constant EXPECTED_FINAL_MESSAGE =
        0xb803a81121df65b74a7bd98bafbeddd5083d76b493d2d457abc2acd280edf33e;

    function setUp() public {
        // Deploy a minimal TldClaimManager for testing
        tldClaimManager = new TldClaimManager();

        // Initialize the domain separator manually
        vm.store(
            address(tldClaimManager),
            bytes32(uint256(10)), // DOMAIN_SEPARATOR storage slot
            EXPECTED_DOMAIN_SEPARATOR
        );

        // Set the signer as valid
        vm.store(
            address(tldClaimManager),
            keccak256(abi.encode(SIGNER_PUBLIC, uint256(9))), // ValidSigner mapping slot
            bytes32(uint256(1))
        );
    }

    function testDebugSignatureStep1_VerifyDomainSeparator() public {
        console.log("=== STEP 1: Domain Separator ===");
        bytes32 contractDomainSeparator = tldClaimManager.DOMAIN_SEPARATOR();
        console.log("Contract Domain Separator:");
        console.logBytes32(contractDomainSeparator);
        console.log("Expected Domain Separator:");
        console.logBytes32(EXPECTED_DOMAIN_SEPARATOR);

        assertEq(contractDomainSeparator, EXPECTED_DOMAIN_SEPARATOR, "Domain separator mismatch");
        console.log("[OK] Domain separator matches");
    }

    function testDebugSignatureStep2_VerifyNamehash() public {
        console.log("=== STEP 2: Namehash Calculation ===");
        bytes32 calculatedNamehash = Namehash.getTldNamehash(DOMAIN);
        console.log("Calculated TLD Namehash:");
        console.logBytes32(calculatedNamehash);
        console.log("Expected TLD Namehash:");
        console.logBytes32(TLD_NAMEHASH);

        assertEq(calculatedNamehash, TLD_NAMEHASH, "TLD namehash mismatch");
        console.log("[OK] TLD namehash matches");
    }

    function testDebugSignatureStep3_VerifyMessageHash() public {
        console.log("=== STEP 3: Message Hash ===");
        bytes32 calculatedMessageHash = keccak256(abi.encodePacked(BURNER, TLD_NAMEHASH));
        console.log("Calculated Message Hash (burner + tldNamehash):");
        console.logBytes32(calculatedMessageHash);
        console.log("Expected Message Hash:");
        console.logBytes32(EXPECTED_MESSAGE_HASH);

        assertEq(calculatedMessageHash, EXPECTED_MESSAGE_HASH, "Message hash mismatch");
        console.log("[OK] Message hash matches");
    }

    function testDebugSignatureStep4_VerifyBurnHash() public {
        console.log("=== STEP 4: Burn Hash (Final Message) ===");
        bytes32 contractBurnHash = tldClaimManager.getBurnHash(BURNER, TLD_NAMEHASH);
        console.log("Contract Burn Hash:");
        console.logBytes32(contractBurnHash);
        console.log("Expected Final Message:");
        console.logBytes32(EXPECTED_FINAL_MESSAGE);

        assertEq(contractBurnHash, EXPECTED_FINAL_MESSAGE, "Burn hash mismatch");
        console.log("[OK] Burn hash matches");
    }

    function testDebugSignatureStep5_ManualEcrecover() public {
        console.log("=== STEP 5: Manual Ecrecover ===");
        address recoveredSigner = ecrecover(EXPECTED_FINAL_MESSAGE, V, R, S);
        console.log("Recovered Signer:");
        console.logAddress(recoveredSigner);
        console.log("Expected Signer:");
        console.logAddress(SIGNER_PUBLIC);

        if (recoveredSigner == SIGNER_PUBLIC) {
            console.log("[OK] Signature recovers to correct signer");
        } else {
            console.log("[FAIL] Signature does NOT recover to correct signer");
        }
    }

    function testDebugSignatureStep6_ValidSignerCheck() public {
        console.log("=== STEP 6: Valid Signer Check ===");

        // First recover the address
        address recoveredSigner = ecrecover(EXPECTED_FINAL_MESSAGE, V, R, S);
        console.log("Recovered Signer:");
        console.logAddress(recoveredSigner);

        // Check if it's a valid signer
        bool isValidSigner = tldClaimManager.ValidSigner(recoveredSigner);
        console.log("Is Valid Signer:");
        console.logBool(isValidSigner);

        if (isValidSigner) {
            console.log("[OK] Recovered signer is authorized");
        } else {
            console.log("[FAIL] Recovered signer is NOT authorized");
        }
    }

    function testDebugSignatureStep7_ContractValidation() public {
        console.log("=== STEP 7: Contract Signature Validation ===");

        try tldClaimManager.checkSignatureValid(BURNER, TLD_NAMEHASH, V, R, S) returns (
            address signer
        ) {
            console.log("[OK] Contract signature validation PASSED");
            console.log("Returned signer:");
            console.logAddress(signer);
        } catch Error(string memory reason) {
            console.log("[FAIL] Contract signature validation FAILED");
            console.log("Reason:");
            console.logString(reason);
        } catch {
            console.log("[FAIL] Contract signature validation FAILED with unknown error");
        }
    }

    function testCompleteSignatureDebug() public {
        console.log("=== COMPLETE SIGNATURE DEBUG ===");
        console.log("");

        this.testDebugSignatureStep1_VerifyDomainSeparator();
        console.log("");

        this.testDebugSignatureStep2_VerifyNamehash();
        console.log("");

        this.testDebugSignatureStep3_VerifyMessageHash();
        console.log("");

        this.testDebugSignatureStep4_VerifyBurnHash();
        console.log("");

        this.testDebugSignatureStep5_ManualEcrecover();
        console.log("");

        this.testDebugSignatureStep6_ValidSignerCheck();
        console.log("");

        this.testDebugSignatureStep7_ContractValidation();
    }

    function testGenerateSignatureWithPrivateKey() public {
        console.log("=== GENERATE SIGNATURE WITH PRIVATE KEY ===");

        // Get the private key from environment
        uint256 signerPrivateKey = vm.envUint("SIGNER_PRIVATE_KEY");
        address derivedPublicKey = vm.addr(signerPrivateKey);

        console.log("Private key derived public address:");
        console.logAddress(derivedPublicKey);
        console.log("Expected signer public address:");
        console.logAddress(SIGNER_PUBLIC);

        if (derivedPublicKey == SIGNER_PUBLIC) {
            console.log("[OK] Private key matches expected public address");
        } else {
            console.log("[FAIL] Private key does NOT match expected public address");
            return;
        }

        // Generate signature using the private key
        bytes32 messageToSign = tldClaimManager.getBurnHash(BURNER, TLD_NAMEHASH);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, messageToSign);

        console.log("Generated signature components:");
        console.log("v:", v);
        console.logBytes32(r);
        console.logBytes32(s);

        console.log("Your frontend signature components:");
        console.log("v:", V);
        console.logBytes32(R);
        console.logBytes32(S);

        // Test the generated signature
        try tldClaimManager.checkSignatureValid(BURNER, TLD_NAMEHASH, v, r, s) returns (
            address signer
        ) {
            console.log("[OK] Generated signature validation PASSED");
            console.log("Returned signer:");
            console.logAddress(signer);
        } catch Error(string memory reason) {
            console.log("[FAIL] Generated signature validation FAILED");
            console.log("Reason:");
            console.logString(reason);
        }
    }
}

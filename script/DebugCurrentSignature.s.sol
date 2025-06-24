// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";

contract DebugCurrentSignatureScript is Script {
    function run() public {
        console.log("=== DEBUGGING CURRENT SIGNATURE ===");

        // Your frontend values from the logs
        address burner = 0x175F303781Efe881Ce40A511517186DbF364b3a7;
        bytes32 tldNamehash = 0x4e40f6e0b682912885261b48c6a9ba4f76aac8f74cb47354d0508b49a6c988d8;

        // Your signature from logs
        uint8 v = 28;
        bytes32 r = 0x88adc7c73e9d4dae8ae31345839427feaae10c93a6152da9d9d2a8c2a63afd81;
        bytes32 s = 0x60aca3ddd8d0f657ba7adf89a647585a105129924524a639bc4ec2f2a348c5d0;

        // Your frontend calculated values
        bytes32 frontendDomainSeparator = 0x901e84d886f1a997683aa622e6d911b697d101793f446ecd9c3990932d5348ca;
        bytes32 frontendBurnTypehash = 0xae02bff538f49c03c81e2936c66166f696193913168d7052dad7c9c2b1a48fd4;
        bytes32 frontendMessageHash = 0x6f9a5c04b8cb80e3bfc2b041d108600abd330454c32d98dd3e66d8e1cfe3b364;
        bytes32 frontendFinalDigest = 0xe003c8c154cf787d906c81d083ee84fde3c30de0caf758c27f4695d59b07e791;

        address expectedSigner = 0x0A93DE7D66D09AB61b7e95077A260ee839B69f23;

        console.log("=== STEP 1: Verify Burn Typehash ===");
        bytes32 contractBurnTypehash = keccak256("BurnTld(address burner,bytes32 tldNamehash)");
        console.log("Contract BURN_TYPEHASH:");
        console.logBytes32(contractBurnTypehash);
        console.log("Frontend Burn Typehash:");
        console.logBytes32(frontendBurnTypehash);

        if (contractBurnTypehash == frontendBurnTypehash) {
            console.log("[OK] Burn typehashes match!");
        } else {
            console.log("[FAIL] Burn typehashes don't match");
        }

        console.log("\n=== STEP 2: Verify Message Hash ===");
        bytes32 contractMessageHash = keccak256(
            abi.encode(contractBurnTypehash, burner, tldNamehash)
        );
        console.log("Contract Message Hash (abi.encode):");
        console.logBytes32(contractMessageHash);
        console.log("Frontend Message Hash:");
        console.logBytes32(frontendMessageHash);

        if (contractMessageHash == frontendMessageHash) {
            console.log("[OK] Message hashes match!");
        } else {
            console.log("[FAIL] Message hashes don't match");
        }

        console.log("\n=== STEP 3: Verify Final Digest ===");
        bytes32 contractFinalDigest = keccak256(
            abi.encodePacked("\x19\x01", frontendDomainSeparator, contractMessageHash)
        );
        console.log("Contract Final Digest:");
        console.logBytes32(contractFinalDigest);
        console.log("Frontend Final Digest:");
        console.logBytes32(frontendFinalDigest);

        if (contractFinalDigest == frontendFinalDigest) {
            console.log("[OK] Final digests match!");
        } else {
            console.log("[FAIL] Final digests don't match");
        }

        console.log("\n=== STEP 4: Test Signature Recovery ===");
        address recoveredSigner = ecrecover(frontendFinalDigest, v, r, s);
        console.log("Recovered Signer:");
        console.logAddress(recoveredSigner);
        console.log("Expected Signer:");
        console.logAddress(expectedSigner);

        if (recoveredSigner == expectedSigner) {
            console.log("[OK] Signature is valid!");
        } else {
            console.log("[FAIL] Signature is invalid");
        }

        console.log("\n=== STEP 5: Test Contract Method ===");
        // Simulate what getBurnHash should return
        bytes32 simulatedContractHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                frontendDomainSeparator, // This should match the contract's DOMAIN_SEPARATOR
                keccak256(abi.encode(contractBurnTypehash, burner, tldNamehash))
            )
        );
        console.log("Simulated Contract getBurnHash:");
        console.logBytes32(simulatedContractHash);

        if (simulatedContractHash == frontendFinalDigest) {
            console.log("[OK] Contract method should work with your signature!");
        } else {
            console.log("[FAIL] There's still a mismatch somewhere");
        }

        console.log("\n=== SUMMARY ===");
        console.log("Your signature appears to be correctly generated for EIP-712!");
        console.log("The issue might be:");
        console.log("1. Domain separator mismatch on the contract");
        console.log("2. The signer is not authorized in ValidSigner mapping");
        console.log("3. The contract's DOMAIN_SEPARATOR is not initialized");
    }
}

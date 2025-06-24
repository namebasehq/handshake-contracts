// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";

contract TestFinalSignatureScript is Script {
    function run() public {
        console.log("=== FINAL SIGNATURE TEST ===");
        
        // Your frontend values
        address burner = 0x91769843CEc84Adcf7A48DF9DBd9694A39f44b42;
        bytes32 tldNamehash = 0x4e40f6e0b682912885261b48c6a9ba4f76aac8f74cb47354d0508b49a6c988d8;
        
        // Values from your logs
        bytes32 frontendDomainSeparator = 0x901e84d886f1a997683aa622e6d911b697d101793f446ecd9c3990932d5348ca;
        bytes32 frontendBurnTypehash = 0xae02bff538f49c03c81e2936c66166f696193913168d7052dad7c9c2b1a48fd4;
        bytes32 frontendMessageHash = 0x65b77f522ef97b85b232525515bb6c838477772ab2c1b2f1a32d7b899ccaa6c2;
        bytes32 frontendFinalDigest = 0x7e0305ab985f547245b0bc6ef35f156e1d98cfba46154e5275c1321c7bdc74c7;
        
        address expectedSigner = 0x0A93DE7D66D09AB61b7e95077A260ee839B69f23;
        
        console.log("=== STEP 1: Verify BurnTld Typehash ===");
        bytes32 burnTldTypehash = keccak256("BurnTld(address burner,bytes32 tldNamehash)");
        console.log("Calculated BurnTld typehash:");
        console.logBytes32(burnTldTypehash);
        console.log("Frontend typehash:");
        console.logBytes32(frontendBurnTypehash);
        
        if (burnTldTypehash == frontendBurnTypehash) {
            console.log("[OK] Typehashes match!");
        } else {
            console.log("[FAIL] Typehashes don't match");
        }
        
        console.log("\n=== STEP 2: Calculate Message Hash ===");
        bytes32 calculatedMessageHash = keccak256(abi.encode(frontendBurnTypehash, burner, tldNamehash));
        console.log("Calculated message hash:");
        console.logBytes32(calculatedMessageHash);
        console.log("Frontend message hash:");
        console.logBytes32(frontendMessageHash);
        
        if (calculatedMessageHash == frontendMessageHash) {
            console.log("[OK] Message hashes match!");
        } else {
            console.log("[FAIL] Message hashes don't match");
        }
        
        console.log("\n=== STEP 3: Calculate Final Digest ===");
        bytes32 calculatedFinalDigest = keccak256(abi.encodePacked(
            "\x19\x01",
            frontendDomainSeparator,
            frontendMessageHash
        ));
        console.log("Calculated final digest:");
        console.logBytes32(calculatedFinalDigest);
        console.log("Frontend final digest:");
        console.logBytes32(frontendFinalDigest);
        
        if (calculatedFinalDigest == frontendFinalDigest) {
            console.log("[OK] Final digests match!");
        } else {
            console.log("[FAIL] Final digests don't match");
        }
        
        console.log("\n=== STEP 4: Generate Correct Signature ===");
        uint256 privateKey = vm.envUint("SIGNER_PRIVATE_KEY");
        address derivedAddress = vm.addr(privateKey);
        console.log("Private key derives to:");
        console.logAddress(derivedAddress);
        console.log("Expected signer:");
        console.logAddress(expectedSigner);
        
        if (derivedAddress == expectedSigner) {
            console.log("[OK] Private key is correct!");
        } else {
            console.log("[FAIL] Private key doesn't match expected signer");
            return;
        }
        
        // Generate signature for the exact frontend digest
        (uint8 correctV, bytes32 correctR, bytes32 correctS) = vm.sign(privateKey, frontendFinalDigest);
        
        console.log("\n=== CORRECT SIGNATURE FOR YOUR FRONTEND ===");
        console.log("Use these values in your UI:");
        console.log("v:", correctV);
        console.log("r:");
        console.logBytes32(correctR);
        console.log("s:");
        console.logBytes32(correctS);
        
        // Verify the signature works
        address recovered = ecrecover(frontendFinalDigest, correctV, correctR, correctS);
        console.log("\nSignature verification:");
        console.log("Recovered address:");
        console.logAddress(recovered);
        
        if (recovered == expectedSigner) {
            console.log("[OK] Signature is valid!");
        } else {
            console.log("[FAIL] Signature is invalid");
        }
        
        console.log("\n=== CONTRACT COMPARISON ===");
        // Get what the contract returns
        bytes32 contractHash = 0xf349ff65a28e12f389e68ce5e6473350b5dba805ec5a1c06ac25ae5cf68eac6c; // From previous call
        console.log("Contract getBurnHash returns:");
        console.logBytes32(contractHash);
        console.log("Frontend final digest:");
        console.logBytes32(frontendFinalDigest);
        
        if (contractHash == frontendFinalDigest) {
            console.log("[OK] Contract and frontend match!");
        } else {
            console.log("[FAIL] Contract and frontend don't match");
            console.log("This means the contract implementation still doesn't match your frontend");
        }
    }
} 
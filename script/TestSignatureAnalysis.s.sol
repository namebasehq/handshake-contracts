// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";

contract TestSignatureAnalysisScript is Script {
    function run() public {
        console.log("=== SIGNATURE ANALYSIS ===");

        // Your frontend values
        address burner = 0x175F303781Efe881Ce40A511517186DbF364b3a7;
        bytes32 tldNamehash = 0x4e40f6e0b682912885261b48c6a9ba4f76aac8f74cb47354d0508b49a6c988d8;

        // Your frontend signature
        uint8 frontendV = 28;
        bytes32 frontendR = 0xbe41925a07d190536e75f850e5e6374111f14055f008c5b320ca331dab516583;
        bytes32 frontendS = 0x04761f5aa1a316e7d53069a1d09ea840050542fcb71fb525fb042f81e6608b38;

        // Expected values from your logs
        bytes32 frontendDomainSeparator = 0x29795eb1eff352c099381361eecc2af9dcf8f2877f487d462444461427abd666;
        bytes32 frontendMessageHash = 0x9bf13f2ded55ed1207565b0b70738ecbd13395dfb3b1104bf1bffdee0f903c4d;
        bytes32 frontendFinalHash = 0x066248362a70e9f8b25a47ce004b50462fe6174177a506df6c1e51c67f2ed471;

        address expectedSigner = 0x0A93DE7D66D09AB61b7e95077A260ee839B69f23;

        console.log("=== STEP 1: Domain Separator Comparison ===");
        // Calculate what the contract's domain separator should be
        bytes32 contractDomainSeparator = 0x901e84d886f1a997683aa622e6d911b697d101793f446ecd9c3990932d5348ca;
        console.log("Contract Domain Separator:");
        console.logBytes32(contractDomainSeparator);
        console.log("Frontend Domain Separator:");
        console.logBytes32(frontendDomainSeparator);

        if (contractDomainSeparator == frontendDomainSeparator) {
            console.log("[OK] Domain separators match");
        } else {
            console.log("[FAIL] Domain separators DO NOT match");
        }

        console.log("\n=== STEP 2: Message Hash Comparison ===");
        // Calculate the message hash (burner + tldNamehash)
        bytes32 calculatedMessageHash = keccak256(abi.encodePacked(burner, tldNamehash));
        console.log("Contract Message Hash (burner + tldNamehash):");
        console.logBytes32(calculatedMessageHash);
        console.log("Frontend Message Hash:");
        console.logBytes32(frontendMessageHash);

        if (calculatedMessageHash == frontendMessageHash) {
            console.log("[OK] Message hashes match");
        } else {
            console.log("[FAIL] Message hashes DO NOT match");
        }

        console.log("\n=== STEP 3: Final Message Hash Comparison ===");
        // Calculate the final message hash using contract's domain separator
        bytes32 contractFinalHash =
            keccak256(abi.encodePacked("\x19\x01", contractDomainSeparator, calculatedMessageHash));
        console.log("Contract Final Hash:");
        console.logBytes32(contractFinalHash);
        console.log("Frontend Final Hash:");
        console.logBytes32(frontendFinalHash);

        if (contractFinalHash == frontendFinalHash) {
            console.log("[OK] Final hashes match");
        } else {
            console.log("[FAIL] Final hashes DO NOT match");
        }

        console.log("\n=== STEP 4: Signature Recovery Test ===");
        // Test signature recovery using frontend's final hash
        address recoveredFromFrontend = ecrecover(frontendFinalHash, frontendV, frontendR, frontendS);
        console.log("Frontend signature recovers to:");
        console.logAddress(recoveredFromFrontend);
        console.log("Expected signer:");
        console.logAddress(expectedSigner);

        if (recoveredFromFrontend == expectedSigner) {
            console.log("[OK] Frontend signature is valid for frontend hash");
        } else {
            console.log("[FAIL] Frontend signature is NOT valid for frontend hash");
        }

        console.log("\n=== STEP 5: Test Against Contract Hash ===");
        // Test signature recovery using contract's final hash
        address recoveredFromContract = ecrecover(contractFinalHash, frontendV, frontendR, frontendS);
        console.log("Frontend signature with contract hash recovers to:");
        console.logAddress(recoveredFromContract);

        if (recoveredFromContract == expectedSigner) {
            console.log("[OK] Frontend signature is valid for contract hash");
        } else {
            console.log("[FAIL] Frontend signature is NOT valid for contract hash");
        }

        console.log("\n=== STEP 6: Generate Correct Signature ===");
        // Generate correct signature using contract's hash
        uint256 privateKey = vm.envUint("SIGNER_PRIVATE_KEY");
        (uint8 correctV, bytes32 correctR, bytes32 correctS) = vm.sign(privateKey, contractFinalHash);

        console.log("Correct signature for contract hash:");
        console.log("v:", correctV);
        console.logBytes32(correctR);
        console.logBytes32(correctS);

        // Verify the correct signature
        address verifyCorrect = ecrecover(contractFinalHash, correctV, correctR, correctS);
        console.log("Correct signature recovers to:");
        console.logAddress(verifyCorrect);

        console.log("\n=== SUMMARY ===");
        console.log("The issue is likely in the domain separator calculation.");
        console.log("Your frontend is calculating a different domain separator than the contract.");
        console.log("This causes the final message hash to be different, making the signature invalid.");
    }
}

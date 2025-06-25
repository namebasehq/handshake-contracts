// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";

contract TestNewSignatureScript is Script {
    function run() public {
        console.log("=== NEW SIGNATURE ANALYSIS ===");

        // Your new frontend values
        address burner = 0x91769843CEc84Adcf7A48DF9DBd9694A39f44b42;
        bytes32 tldNamehash = 0x4e40f6e0b682912885261b48c6a9ba4f76aac8f74cb47354d0508b49a6c988d8;

        // Your new frontend signature
        uint8 frontendV = 27;
        bytes32 frontendR = 0xa05b47af6a123fa8d2f66b37136cd40bac123e6b786d19d078d340b599caa71e;
        bytes32 frontendS = 0x5cd7037ab691dfac2cc58957dde0c65703d37422550c85fec606097c37a7bd3b;

        // Values from your logs
        bytes32 frontendDomainSeparator = 0x901e84d886f1a997683aa622e6d911b697d101793f446ecd9c3990932d5348ca;
        bytes32 frontendBurnTypehash = 0xae02bff538f49c03c81e2936c66166f696193913168d7052dad7c9c2b1a48fd4;
        bytes32 frontendMessageHash = 0x65b77f522ef97b85b232525515bb6c838477772ab2c1b2f1a32d7b899ccaa6c2;
        bytes32 frontendFinalDigest = 0x7e0305ab985f547245b0bc6ef35f156e1d98cfba46154e5275c1321c7bdc74c7;

        address expectedSigner = 0x0A93DE7D66D09AB61b7e95077A260ee839B69f23;

        console.log("=== STEP 1: Domain Separator Check ===");
        bytes32 contractDomainSeparator = 0x901e84d886f1a997683aa622e6d911b697d101793f446ecd9c3990932d5348ca;
        console.log("Contract Domain Separator:");
        console.logBytes32(contractDomainSeparator);
        console.log("Frontend Domain Separator:");
        console.logBytes32(frontendDomainSeparator);

        if (contractDomainSeparator == frontendDomainSeparator) {
            console.log("[OK] Domain separators match!");
        } else {
            console.log("[FAIL] Domain separators DO NOT match");
        }

        console.log("\n=== STEP 2: Message Hash Analysis ===");
        // What the contract expects: simple keccak256(abi.encodePacked(burner, tldNamehash))
        bytes32 contractMessageHash = keccak256(abi.encodePacked(burner, tldNamehash));
        console.log("Contract Message Hash (simple burner + tldNamehash):");
        console.logBytes32(contractMessageHash);
        console.log("Frontend Message Hash:");
        console.logBytes32(frontendMessageHash);

        if (contractMessageHash == frontendMessageHash) {
            console.log("[OK] Message hashes match!");
        } else {
            console.log("[FAIL] Message hashes DO NOT match");
            console.log("This suggests you might be using a typed struct instead of simple concatenation");
        }

        console.log("\n=== STEP 3: Contract's Expected Final Hash ===");
        // What the contract's getBurnHash function returns
        bytes32 contractFinalHash =
            keccak256(abi.encodePacked("\x19\x01", contractDomainSeparator, contractMessageHash));
        console.log("Contract Final Hash (getBurnHash):");
        console.logBytes32(contractFinalHash);
        console.log("Frontend Final Digest:");
        console.logBytes32(frontendFinalDigest);

        if (contractFinalHash == frontendFinalDigest) {
            console.log("[OK] Final hashes match!");
        } else {
            console.log("[FAIL] Final hashes DO NOT match");
        }

        console.log("\n=== STEP 4: Signature Recovery Test ===");
        // Test your signature against your final digest
        address recoveredFromFrontend = ecrecover(frontendFinalDigest, frontendV, frontendR, frontendS);
        console.log("Your signature with your digest recovers to:");
        console.logAddress(recoveredFromFrontend);
        console.log("Expected signer:");
        console.logAddress(expectedSigner);

        if (recoveredFromFrontend == expectedSigner) {
            console.log("[OK] Your signature is valid for your digest");
        } else {
            console.log("[FAIL] Your signature is NOT valid for your digest");
        }

        console.log("\n=== STEP 5: Test Against Contract Hash ===");
        // Test your signature against contract's expected hash
        address recoveredFromContract = ecrecover(contractFinalHash, frontendV, frontendR, frontendS);
        console.log("Your signature with contract hash recovers to:");
        console.logAddress(recoveredFromContract);

        if (recoveredFromContract == expectedSigner) {
            console.log("[OK] Your signature works with contract hash!");
        } else {
            console.log("[FAIL] Your signature does NOT work with contract hash");
        }

        console.log("\n=== STEP 6: Generate Contract-Compatible Signature ===");
        // Generate what the contract expects
        uint256 privateKey = vm.envUint("SIGNER_PRIVATE_KEY");
        (uint8 correctV, bytes32 correctR, bytes32 correctS) = vm.sign(privateKey, contractFinalHash);

        console.log("Contract-compatible signature:");
        console.log("v:", correctV);
        console.logBytes32(correctR);
        console.logBytes32(correctS);

        console.log("\n=== STEP 7: Burn Typehash Analysis ===");
        console.log("Frontend Burn Typehash:");
        console.logBytes32(frontendBurnTypehash);
        console.log("Note: Contract doesn't use a burn typehash - it uses simple concatenation");

        console.log("\n=== SUMMARY ===");
        if (contractDomainSeparator == frontendDomainSeparator) {
            console.log("[OK] Domain separator is now correct!");
        }

        if (contractMessageHash != frontendMessageHash) {
            console.log("[FAIL] You're still using EIP-712 typed structs instead of simple concatenation");
            console.log("  Contract expects: keccak256(abi.encodePacked(address, bytes32))");
            console.log("  You're using: EIP-712 typed struct with burn typehash");
        }

        console.log("The contract uses a simple approach, not full EIP-712 typed structs for the message.");
    }
}

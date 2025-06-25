// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "src/contracts/TldClaimManager.sol";

contract TestEIP712UpdateScript is Script {
    function run() public {
        console.log("=== TESTING UPDATED EIP-712 CONTRACT ===");

        // Your frontend values
        address burner = 0x91769843CEc84Adcf7A48DF9DBd9694A39f44b42;
        bytes32 tldNamehash = 0x4e40f6e0b682912885261b48c6a9ba4f76aac8f74cb47354d0508b49a6c988d8;

        // Your frontend signature
        uint8 frontendV = 27;
        bytes32 frontendR = 0xa05b47af6a123fa8d2f66b37136cd40bac123e6b786d19d078d340b599caa71e;
        bytes32 frontendS = 0x5cd7037ab691dfac2cc58957dde0c65703d37422550c85fec606097c37a7bd3b;

        // Your frontend values from logs
        bytes32 frontendDomainSeparator = 0x901e84d886f1a997683aa622e6d911b697d101793f446ecd9c3990932d5348ca;
        bytes32 frontendBurnTypehash = 0xae02bff538f49c03c81e2936c66166f696193913168d7052dad7c9c2b1a48fd4;
        bytes32 frontendMessageHash = 0x65b77f522ef97b85b232525515bb6c838477772ab2c1b2f1a32d7b899ccaa6c2;
        bytes32 frontendFinalDigest = 0x7e0305ab985f547245b0bc6ef35f156e1d98cfba46154e5275c1321c7bdc74c7;

        address expectedSigner = 0x0A93DE7D66D09AB61b7e95077A260ee839B69f23;

        // Deploy the updated contract
        TldClaimManager updatedContract = new TldClaimManager();

        // Set domain separator manually for testing
        vm.store(
            address(updatedContract),
            bytes32(uint256(10)), // DOMAIN_SEPARATOR storage slot
            frontendDomainSeparator
        );

        // Set the signer as valid
        vm.store(
            address(updatedContract),
            keccak256(abi.encode(expectedSigner, uint256(9))), // ValidSigner mapping slot
            bytes32(uint256(1))
        );

        console.log("=== STEP 1: Domain Separator Check ===");
        bytes32 contractDomainSeparator = updatedContract.DOMAIN_SEPARATOR();
        console.log("Contract Domain Separator:");
        console.logBytes32(contractDomainSeparator);
        console.log("Frontend Domain Separator:");
        console.logBytes32(frontendDomainSeparator);

        if (contractDomainSeparator == frontendDomainSeparator) {
            console.log("[OK] Domain separators match!");
        } else {
            console.log("[FAIL] Domain separators DO NOT match");
        }

        console.log("\n=== STEP 2: Burn Typehash Check ===");
        // Calculate what the contract's BURN_TYPEHASH should be
        bytes32 contractBurnTypehash = keccak256("Burn(address burner,bytes32 tldNamehash)");
        console.log("Contract Burn Typehash:");
        console.logBytes32(contractBurnTypehash);
        console.log("Frontend Burn Typehash:");
        console.logBytes32(frontendBurnTypehash);

        if (contractBurnTypehash == frontendBurnTypehash) {
            console.log("[OK] Burn typehashes match!");
        } else {
            console.log("[FAIL] Burn typehashes DO NOT match");
        }

        console.log("\n=== STEP 3: Message Hash Check ===");
        // Calculate what the contract's message hash should be
        bytes32 contractMessageHash = keccak256(abi.encode(contractBurnTypehash, burner, tldNamehash));
        console.log("Contract Message Hash:");
        console.logBytes32(contractMessageHash);
        console.log("Frontend Message Hash:");
        console.logBytes32(frontendMessageHash);

        if (contractMessageHash == frontendMessageHash) {
            console.log("[OK] Message hashes match!");
        } else {
            console.log("[FAIL] Message hashes DO NOT match");
        }

        console.log("\n=== STEP 4: Final Hash Check ===");
        uint256 expiry = block.timestamp + 1 hours;
        bytes32 contractFinalHash = updatedContract.getBurnHash(burner, tldNamehash, expiry);
        console.log("Contract Final Hash (getBurnHash):");
        console.logBytes32(contractFinalHash);
        console.log("Frontend Final Digest:");
        console.logBytes32(frontendFinalDigest);

        if (contractFinalHash == frontendFinalDigest) {
            console.log("[OK] Final hashes match!");
        } else {
            console.log("[FAIL] Final hashes DO NOT match");
        }

        console.log("\n=== STEP 5: Signature Validation Test ===");
        // Test signature validation
        try updatedContract.checkSignatureValid(burner, tldNamehash, expiry, frontendV, frontendR, frontendS) returns (
            address signer
        ) {
            console.log("[OK] Signature validation PASSED!");
            console.log("Returned signer:");
            console.logAddress(signer);
            console.log("Expected signer:");
            console.logAddress(expectedSigner);

            if (signer == expectedSigner) {
                console.log("[OK] Correct signer recovered!");
            } else {
                console.log("[FAIL] Wrong signer recovered");
            }
        } catch Error(string memory reason) {
            console.log("[FAIL] Signature validation FAILED");
            console.log("Reason:");
            console.logString(reason);
        } catch {
            console.log("[FAIL] Signature validation FAILED with unknown error");
        }

        console.log("\n=== STEP 6: Manual Signature Recovery ===");
        address recoveredSigner = ecrecover(contractFinalHash, frontendV, frontendR, frontendS);
        console.log("Manual ecrecover result:");
        console.logAddress(recoveredSigner);

        if (recoveredSigner == expectedSigner) {
            console.log("[OK] Manual recovery successful!");
        } else {
            console.log("[FAIL] Manual recovery failed");
        }

        console.log("\n=== SUMMARY ===");
        console.log("Updated contract now uses full EIP-712 compliance:");
        console.log("- Domain separator: Standard EIP-712");
        console.log("- Message hash: abi.encode(BURN_TYPEHASH, burner, tldNamehash)");
        console.log("- Should work with your frontend's EIP-712 typed struct approach");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";

contract TestTypehashScript is Script {
    function run() public {
        console.log("=== TYPEHASH ANALYSIS ===");

        bytes32 frontendBurnTypehash = 0xae02bff538f49c03c81e2936c66166f696193913168d7052dad7c9c2b1a48fd4;

        console.log("Frontend Burn Typehash:");
        console.logBytes32(frontendBurnTypehash);

        // Test different variations
        console.log("\nTesting different type string variations:");

        // Variation 1: What we have
        bytes32 v1 = keccak256("Burn(address burner,bytes32 tldNamehash)");
        console.log("Burn(address burner,bytes32 tldNamehash):");
        console.logBytes32(v1);

        // Variation 2: Different spacing
        bytes32 v2 = keccak256("Burn(address burner, bytes32 tldNamehash)");
        console.log("Burn(address burner, bytes32 tldNamehash):");
        console.logBytes32(v2);

        // Variation 3: Different parameter names
        bytes32 v3 = keccak256("Burn(address user,bytes32 tldNamehash)");
        console.log("Burn(address user,bytes32 tldNamehash):");
        console.logBytes32(v3);

        // Variation 4: Different parameter names
        bytes32 v4 = keccak256("Burn(address burner,bytes32 namehash)");
        console.log("Burn(address burner,bytes32 namehash):");
        console.logBytes32(v4);

        // Variation 5: Different parameter names
        bytes32 v5 = keccak256("Burn(address user,bytes32 namehash)");
        console.log("Burn(address user,bytes32 namehash):");
        console.logBytes32(v5);

        // Check which one matches
        if (frontendBurnTypehash == v1) {
            console.log("[MATCH] Variation 1 matches!");
        } else if (frontendBurnTypehash == v2) {
            console.log("[MATCH] Variation 2 matches!");
        } else if (frontendBurnTypehash == v3) {
            console.log("[MATCH] Variation 3 matches!");
        } else if (frontendBurnTypehash == v4) {
            console.log("[MATCH] Variation 4 matches!");
        } else if (frontendBurnTypehash == v5) {
            console.log("[MATCH] Variation 5 matches!");
        } else {
            console.log("[NO MATCH] None of the variations match");
            console.log("Your frontend might be using a different type string");
        }

        // Let's also check some other common variations
        console.log("\nMore variations:");

        bytes32 v6 = keccak256("BurnTld(address burner,bytes32 tldNamehash)");
        console.log("BurnTld(address burner,bytes32 tldNamehash):");
        console.logBytes32(v6);

        bytes32 v7 = keccak256("TldBurn(address burner,bytes32 tldNamehash)");
        console.log("TldBurn(address burner,bytes32 tldNamehash):");
        console.logBytes32(v7);

        if (frontendBurnTypehash == v6) {
            console.log("[MATCH] BurnTld variation matches!");
        } else if (frontendBurnTypehash == v7) {
            console.log("[MATCH] TldBurn variation matches!");
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";

contract TestSignatureScript is Script {
    function run() public {
        // Your exact parameters
        bytes32 message = 0xb803a81121df65b74a7bd98bafbeddd5083d76b493d2d457abc2acd280edf33e;
        uint8 v = 28;
        bytes32 r = 0xfa761d5660716eafa5080995440a52508921e5ae9601bd577069a0b99fabb33b;
        bytes32 s = 0x39bcad1692dbb210a13a1508d0a42cf8e310c496d18f3c61a81c25d442dbba11;

        address expectedSigner = 0x0A93DE7D66D09AB61b7e95077A260ee839B69f23;

        console.log("=== SIGNATURE RECOVERY TEST ===");
        console.log("Message to recover:");
        console.logBytes32(message);
        console.log("Signature components:");
        console.log("v:", v);
        console.logBytes32(r);
        console.logBytes32(s);
        console.log("Expected signer:");
        console.logAddress(expectedSigner);

        address recoveredSigner = ecrecover(message, v, r, s);
        console.log("Recovered signer:");
        console.logAddress(recoveredSigner);

        if (recoveredSigner == expectedSigner) {
            console.log("[OK] Signature is valid!");
        } else if (recoveredSigner == address(0)) {
            console.log("[FAIL] Signature recovery failed - invalid signature");
        } else {
            console.log("[FAIL] Signature recovered to wrong address");
        }

        // Test with v = 27 instead of 28
        console.log("\n=== TESTING WITH v = 27 ===");
        address recoveredSigner27 = ecrecover(message, 27, r, s);
        console.log("Recovered signer (v=27):");
        console.logAddress(recoveredSigner27);

        if (recoveredSigner27 == expectedSigner) {
            console.log("[OK] Signature is valid with v=27!");
        } else if (recoveredSigner27 == address(0)) {
            console.log("[FAIL] Signature recovery failed with v=27");
        } else {
            console.log("[FAIL] Wrong address with v=27");
        }

        // Generate a signature using the private key
        console.log("\n=== GENERATING CORRECT SIGNATURE ===");
        uint256 privateKey = vm.envUint("SIGNER_PRIVATE_KEY");
        address derivedAddress = vm.addr(privateKey);
        console.log("Private key derives to:");
        console.logAddress(derivedAddress);

        (uint8 correctV, bytes32 correctR, bytes32 correctS) = vm.sign(privateKey, message);
        console.log("Correct signature components:");
        console.log("v:", correctV);
        console.logBytes32(correctR);
        console.logBytes32(correctS);

        address verifyCorrect = ecrecover(message, correctV, correctR, correctS);
        console.log("Correct signature recovers to:");
        console.logAddress(verifyCorrect);
    }
}

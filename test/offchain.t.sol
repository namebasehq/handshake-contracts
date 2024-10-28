// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract SignatureVerification is Test {
    event LogBytes(string message, bytes data);
    event LogAddress(string message, address data);
    event LogUint(string message, uint256 data);

    error CCIPReadExpired(uint64 expires);
    error CCIPReadUntrusted(address signed, address signer);

    function verifyOffchain(bytes memory ccip, bytes memory carry)
        internal
        returns (bytes memory request, bytes memory response)
    {
        bytes memory sig;
        uint64 expires;
        (response, expires, sig) = abi.decode(ccip, (bytes, uint64, bytes));

        console.logBytes(response);
        console.log("Expires", expires);
        console.logBytes(sig);

        // Logging the expires value
        emit LogUint("Expires", expires);

        // if (expires < block.timestamp) revert CCIPReadExpired(expires);
        address signer;
        (request, signer) = abi.decode(carry, (bytes, address));
        console.log("here");
        // Logging the request and signer
        emit LogBytes("Request", request);
        emit LogAddress("Signer", signer);

        bytes32 hash =
            keccak256(abi.encodePacked(hex"1900", address(this), expires, keccak256(request), keccak256(response)));

        // Logging the hash
        emit LogBytes("Hash", abi.encodePacked(hash));

        address signed = ECDSA.recover(hash, sig);

        // Logging the signed address
        emit LogAddress("Signed Address", signed);

        if (signed != signer) revert CCIPReadUntrusted(signed, signer);
    }

    function testVerifyOffchain() public {
        // Sample data
<<<<<<< HEAD
        bytes memory carry = hex"3b3b57de109b9fc71e34c7ef80b48cde985901c9a2d1339ab6017745bf9b36a019852a2c";
        bytes memory ccip =
            hex"000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000664c6da400000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000020000000000000000000000000175f303781efe881ce40a511517186dbf364b3a70000000000000000000000000000000000000000000000000000000000000041f532837c21d6e116315f9a9d72e94022fcc49a3f28ca879ca9d34a7f115231895c2b7fadd1b70531a3d3d6d11ffae67a35fa4f20fc9f553d21e134918a80ae981b00000000000000000000000000000000000000000000000000000000000000";
=======
        bytes
            memory carry = hex"3b3b57de109b9fc71e34c7ef80b48cde985901c9a2d1339ab6017745bf9b36a019852a2c";
        bytes
            memory ccip = hex"000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000664c6da400000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000020000000000000000000000000175f303781efe881ce40a511517186dbf364b3a70000000000000000000000000000000000000000000000000000000000000041f532837c21d6e116315f9a9d72e94022fcc49a3f28ca879ca9d34a7f115231895c2b7fadd1b70531a3d3d6d11ffae67a35fa4f20fc9f553d21e134918a80ae981b00000000000000000000000000000000000000000000000000000000000000";
>>>>>>> main

        verifyOffchain(ccip, carry);
    }
}

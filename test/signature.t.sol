// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "utils/RRUtils.sol";
import "utils/BytesUtils.sol";
import "structs/EIP712Domain.sol";

contract SignatureTests is Test {
    bytes32 private EIP712DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    bytes32 public DOMAIN_SEPARATOR;

    function testSig() public {
        DOMAIN_SEPARATOR = hashDomain();

        address buyer = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        bytes32 subdomainHash = 0x243c7f49b47b0c3ebec972b3b29671263571c473d9f9ad8aab143c745acde83f;
        uint256 nonce = 0;

        bytes32 returnVal = getRegistrationHash(buyer, subdomainHash, nonce);

        bytes32 r = 0x899becb0c2609c60b75af6f1a13416ac2011bfa30bea3b7fcd47c9a83274fadf;
        bytes32 s = 0x1a7fa732b7bb9807462b5e4a7370c1bb9a2b7073e656e9f46fe098e622aaf8b2;

        address signer = ecrecover(returnVal, 28, r, s);
        assertEq(signer, 0xdA29bd6a46B89Cc5a5a404663524132D2f7Df10f);
        console.logBytes32(DOMAIN_SEPARATOR);
    }

    function testNewSig() public {
        bytes32 r = 0x899becb0c2609c60b75af6f1a13416ac2011bfa30bea3b7fcd47c9a83274fadf;
        bytes32 s = 0x1a7fa732b7bb9807462b5e4a7370c1bb9a2b7073e656e9f46fe098e622aaf8b2;
        uint8 v = 28;

        bytes32 sd = 0x243c7f49b47b0c3ebec972b3b29671263571c473d9f9ad8aab143c745acde83f;

        checkSignatureValid(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, sd, v, r, s);
    }

    function getRegistrationHash(address buyer, bytes32 subdomainHash, uint256 nonce) public view returns (bytes32) {
        console.log("data hashed");
        console.logBytes32(keccak256(abi.encodePacked(buyer, subdomainHash, nonce)));
        return keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, keccak256(abi.encodePacked(buyer, subdomainHash, nonce)))
        );
    }

    function checkSignatureValid(address buyer, bytes32 subdomainHash, uint8 v, bytes32 r, bytes32 s)
        private
        returns (address)
    {
        DOMAIN_SEPARATOR = hashDomain();

        bytes32 message = getRegistrationHash(buyer, subdomainHash, 0);
        console.log("message");
        console.logBytes32(message);
        console.log("domain_separator");
        console.logBytes32(DOMAIN_SEPARATOR);
        console.log("subdomain hash");
        console.logBytes32(subdomainHash);
        address signer = ecrecover(message, v, r, s);

        console.log("signer", signer);
    }

    function hashDomain() internal view returns (bytes32) {
        EIP712Domain memory eip712Domain = EIP712Domain({
            name: "Namebase",
            version: "1",
            chainId: 31337,
            verifyingContract: 0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6
        });

        return keccak256(
            abi.encodePacked(
                EIP712DOMAIN_TYPEHASH,
                keccak256(bytes(eip712Domain.name)),
                keccak256(bytes(eip712Domain.version)),
                eip712Domain.chainId,
                eip712Domain.verifyingContract
            )
        );
    }
}

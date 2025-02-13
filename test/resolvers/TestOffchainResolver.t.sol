// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "src/contracts/ccip/HnsIdEnsResolver.sol";

contract HnsIdEnsResolverTest is Test {
    HnsIdEnsResolver resolver;

    function setUp() public {
        // Deploy the resolver contract with test parameters
        address[] memory signers = new address[](1);
        signers[0] = address(this);

        resolver = new HnsIdEnsResolver("https://example.com", signers, address(0), address(0));
    }

    function testHexToText() public {
        // DNS Encoded Names (precomputed)
        bytes memory testing11Dns = hex"0974657374696e6731310365746800";
        bytes memory testing666Dns = hex"0a74657374696e673636360365746800";
        bytes memory testing111Dns = hex"0a74657374696e673131310365746800";

        // Expected outputs
        string memory expectedTesting11 = "testing11.eth";
        string memory expectedTesting666 = "testing666.eth";
        string memory expectedTesting111 = "testing111.eth";

        // Run hexToText function
        string memory result11 = resolver.hexToText(testing11Dns);
        string memory result666 = resolver.hexToText(testing666Dns);
        string memory result111 = resolver.hexToText(testing111Dns);

        // Assert equality
        assertEq(result11, expectedTesting11, "testing11.eth failed");
        assertEq(result666, expectedTesting666, "testing666.eth failed");
        assertEq(result111, expectedTesting111, "testing111.eth failed");
    }
}

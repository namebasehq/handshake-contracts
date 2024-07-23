// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.4;

// import "forge-std/Test.sol";
// import "contracts/ccip/OffchainResolver.sol"; // Update this path to where your OffchainResolver contract is located.
// import "mocks/MockEns.sol"; // Mock for testing ownership.

// contract OffchainResolverTest is Test {
//     OffchainResolver resolver;
//     address ensAddress;
//     MockENS ens;

//     error Unauthorized();

//     function setUp() public {

//         address[] memory signers = new address[](1);
//         signers[0] = address(this); // Assume the deployer is a signer for simplicity.

//         ens = new MockENS();
//         ensAddress = address(ens);

//         resolver = new OffchainResolver("https://example.com", signers, ensAddress, address(0));
//     }

//     /// Test initial url setup
//     function testInitialUrl() public {
//         assertEq(resolver.url(), "https://example.com");
//     }

//     /// Test updating signers and checking authorizations
//     function testUpdateSigners() public {
//         address newSigner = address(0xBEEF);
//         address[] memory signers = new address[](1);
//         bool[] memory states = new bool[](1);
//         signers[0] = newSigner;
//         states[0] = true;

//         resolver.updateSigners(signers, states);
//         assertTrue(resolver.signers(newSigner));
//     }

//     /// Test unauthorized access to setting text
//     function testFailUnauthorisedSetText() public {
//         vm.prank(address(0xDEAD));
//         resolver.setText(0x0, "key", "value");
//     }

//     /// Test setting and getting text records
//     function testSetText() public {
//         bytes32 node = keccak256("testnode");

//         ens.mint(uint256(node), address(this));
        
//         resolver.setText(node, "email", "test@example.com");
//         assertEq(resolver.tldText(node, "email"), "test@example.com");

//         vm.prank(address(0xDEAD));
//         vm.expectRevert(Unauthorized.selector);
//         resolver.setText(node, "test", "test@example.com");
//     }

//     /// Test URL updates by owner only
//     function testUpdateUrl() public {
//         resolver.updateUrl("https://newexample.com");
//         assertEq(resolver.url(), "https://newexample.com");

//         vm.prank(address(0xDEAD));
//         vm.expectRevert("Ownable: caller is not the owner");
//         resolver.updateUrl("https://fail.com");
//     }

// }

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import {Namehash} from "utils/Namehash.sol"; //
import "src/contracts/ccip/OffchainResolver.sol";

contract UpdateOffchainResolverScript is Script {
    function run() public {
        vm.startBroadcast();

        address resolverAddress = 0x206722AB27bA0Cd6CB2B4586a728252d7B77c254;
        OffchainResolver resolver = OffchainResolver(resolverAddress);

        // Update the URL for OffchainResolver
        // string memory newUrl = "https://new-url.com/api/gateway";
        // resolver.updateUrl(newUrl);

        // Calculate the namehash for "testing123.eth"
        bytes32 testNode = Namehash.getDomainNamehash("testing123.eth");

        console.logBytes32(testNode);

        // Set a text record for "testing123.eth"
        string memory key = "hns1";
        string memory value = "exampleValue";
        resolver.setText(testNode, key, value);

        console.log("Updated URL and set text record for testing123.eth");

        vm.stopBroadcast();
    }
}

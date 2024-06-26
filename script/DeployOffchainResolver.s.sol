// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "src/contracts/ccip/OffchainResolver.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployOffchainResolverScript is Script {
    function setUp() public {
        // Setup can be used to initialize contract instances, variables, etc.
    }

    function run() public {
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        string memory url;
        address[] memory signers = new address[](1);
        address ens;

        uint256 chainId = block.chainid;
        console.log("Deploying to chain ID:", chainId);

        if (chainId == 1) { // Mainnet
            url = "https://hns.id/api/gateway/ccip?sender={sender}&data={data}";
            signers[0] = 0x9b6435e0e73d40f8a64fe5094e4ea462a54a078b;
            ens = address(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e); // Mainnet ENS address
        } else if (chainId == 11155111) { // Sepolia
            url = "https://hnst.id/api/gateway/ccip?sender={sender}&data={data}";
            signers[0] = 0xdEC45E28975FF38ACBb37Af9Eaa64493c3aDa126;
            ens = address(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e); // sepolia address the same
        } else {
            revert("Unsupported network");
        }

        // Deploy the off-chain resolver
        OffchainResolver offchainResolver = new OffchainResolver(url, signers, ens);
        console.log("OffchainResolver deployed at: ", address(offchainResolver));

        vm.stopBroadcast();
    }
}

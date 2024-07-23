// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "src/contracts/ccip/OffchainResolver.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployOffchainResolverScript is Script {
    function setUp() public {
      
    }

    

    // forge script script/DeployOffchainResolver.s.sol:DeployOffchainResolverScript --private-key $GOERLI_DEPLOYER_PRIVATE_KEY --rpc-url $GOERLI_L1_RPC_URL --etherscan-api-key $ETHERSCAN_L1_API_KEY --verify --retries 10 --delay 10 --broadcast -vv
    function run() public {
        vm.startBroadcast(vm.envUint("GOERLI_DEPLOYER_PRIVATE_KEY"));

        string memory url;
        address[] memory signers = new address[](1);
        address ens;
        address namewrapper;

        uint256 chainId = block.chainid;
        console.log("Deploying to chain ID:", chainId);
        console.log("msg.sender: ", msg.sender);

        if (chainId == 1) { // Mainnet
            url = "https://hns.id/api/gateway/ccip?sender={sender}&data={data}";
            signers[0] = 0x9b6435E0E73d40F8A64fE5094e4ea462a54a078B;
            ens = address(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e); // Mainnet ENS address
            namewrapper = 0xD4416b13d2b3a9aBae7AcD5D6C2BbDBE25686401;
        } else if (chainId == 11155111) { // Sepolia
            url = "https://hns-id-git-ccip-sam-namebase.vercel.app/api/";
            signers[0] = 0xdEC45E28975FF38ACBb37Af9Eaa64493c3aDa126;
            ens = address(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e); // sepolia address the same
            namewrapper = 0x0635513f179D50A207757E05759CbD106d7dFcE8;
        } else {
            revert("Unsupported network");
        }

        // Deploy the off-chain resolver
        OffchainResolver offchainResolver = new OffchainResolver(url, signers, ens, namewrapper);
        console.log("OffchainResolver deployed at: ", address(offchainResolver));

        vm.stopBroadcast();
    }
}

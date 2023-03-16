// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "src/contracts/ccip/OffchainResolver.sol";
import "src/contracts/ccip/SignatureVerifier.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployOffchainResolverScript is Script {
    function setUp() public {}

    //forge script script/DeployOffchainResolver.s.sol:DeployOffchainResolverScript --private-key $DEPLOYER_PRIVATE_KEY --rpc-url $GOERLI_L1_RPC_URL --broadcast -vv

    function run() public {
        // 0x3b935260cd0cb7270515c93655fe2978cac09049

        // 0x79739e06bf116769de105da3d2c617530753cd341c3c874d18ddc473592eaf2b << node

        address[] memory signers = new address[](1);
        signers[0] = 0xdA29bd6a46B89Cc5a5a404663524132D2f7Df10f;
        string memory url = "https://handshake-ccip.hodlthedoor.repl.co/{sender}/{data}.json";

        vm.startBroadcast(vm.envUint("GOERLI_DEPLOYER_PRIVATE_KEY"));

        OffchainResolver offchainResolver = new OffchainResolver(url, signers);

        console.log("Deployed OffchainResolver at address: %s", address(offchainResolver));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "src/contracts/ccip/OffchainResolver.sol";
import "src/contracts/ccip/SignatureVerifier.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployOffchainResolverScript is Script {
    function setUp() public {}

    //forge script script/DeployOffchainResolver.s.sol:DeployOffchainResolverScript --private-key $DEPLOYER_PRIVATE_KEY --rpc-url $RPC_URL --broadcast -vv

    function run() public {
        // 0x3b935260cd0cb7270515c93655fe2978cac09049

        // 0x79739e06bf116769de105da3d2c617530753cd341c3c874d18ddc473592eaf2b << node

        address[] memory signers = new address[](1);
        signers[0] = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        string memory url = "http://localhost:8080/{sender}/{data}.json";

        vm.startBroadcast(vm.envUint("GOERLI_DEPLOYER_PRIVATE_KEY"));

        OffchainResolver offchainResolver = new OffchainResolver(url, signers);

        console.log("Deployed OffchainResolver at address: %s", address(offchainResolver));

        bytes memory data = abi.encodePacked(hex"1896f70a79739e06bf116769de105da3d2c617530753cd341c3c874d18ddc473592eaf2b000000000000000000000000", address(offchainResolver));
    
        address(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e).call(data);

    }
}

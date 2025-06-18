// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import {CrossmintMinter} from "../src/contracts/CrossmintMinter.sol";

contract DeployCrossmintMinterScript is Script {
    function run() public {
        address registrar = 0xfda87CC032cD641ac192027353e5B25261dfe6b3;

        address crossmintAddress = 0xa66b23D9a8a46C284fa5b3f2E2b59Eb5cc3817F4;

        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        CrossmintMinter minter = new CrossmintMinter(registrar);
        minter.updateMinter(crossmintAddress, true);

        console.log("CrossmintMinter deployed to:", address(minter));
        console.log("Using registrar at:", registrar);

        vm.stopBroadcast();
    }
}

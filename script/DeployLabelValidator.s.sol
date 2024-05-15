// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import "contracts/LabelValidator.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployLabelValidatorScript is Script {


    // forge script script/DeployLabelValidator.s.sol:DeployLabelValidatorScript --private-key $DEPLOYER_PRIVATE_KEY --rpc-url $OPT_TEST_RPC  --etherscan-api-key $ETHERSCAN_API_KEY --verify --retries 10 --delay 10 --broadcast -vv

    function run() public {

        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        LabelValidator labelValidator = new LabelValidator();

        console.log("labelValidator address:", address(labelValidator));

        vm.stopBroadcast();
    }


}


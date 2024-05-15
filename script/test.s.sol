// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "contracts/SldRegistrationManager.sol";

// 0x529B2b5B576c27769Ae0aB811F1655012f756C00

// forge script script/test.s.sol:TestScript --private-key $GOERLI_DEPLOYER_PRIVATE_KEY --rpc-url $RPC_URL --etherscan-api-key $ETHERSCAN_API_KEY --verify --retries 10 --delay 10  --broadcast -vv

contract TestScript is Script {
    function run() public {
        vm.startBroadcast(vm.envUint("OWNER_PK"));

        SldRegistrationManager manager = SldRegistrationManager(
            0x529B2b5B576c27769Ae0aB811F1655012f756C00
        );

        address owner = manager.owner();

        console.log("owner: ", owner);

        manager.updateSigner(0xdEC45E28975FF38ACBb37Af9Eaa64493c3aDa126, true);

        bool isValidSigner = manager.ValidSigner(0xdEC45E28975FF38ACBb37Af9Eaa64493c3aDa126);

        console.log("isValidSigner: ", isValidSigner);
    }
}

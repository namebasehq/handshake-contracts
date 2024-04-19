// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {SldStatus, DomainDetails} from "contracts/SldStatus.sol";
import {SldRegistrationManager} from "contracts/SldRegistrationManager.sol";
import {IHandshakeSld} from "interfaces/IHandshakeSld.sol";
import {IHandshakeTld} from "interfaces/IHandshakeTld.sol";
import {HandshakeSld} from "contracts/HandshakeSld.sol";

//forge script script/DeploySldStatus.s.sol:DeploySldStatusScript --private-key $DEPLOYER_PRIVATE_KEY --rpc-url $OPT_RPC --broadcast -vv

contract DeploySldStatusScript is Script {
    address constant SLD_ADDRESS = 0x7963bfA8F8f914b9776ac6259a8C39965d26f42F;
    address constant TLD_ADDRESS = 0x01eBCf32e4b5da0167eaacEA1050B2be63122B6f;
    address constant MANAGER_ADDRESS = 0xfda87CC032cD641ac192027353e5B25261dfe6b3;

    function setUp() public {}

    function run() public {
      // vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));


        SldStatus status = SldStatus(
            0x93f7F30736709cC6Df4b46C58f5C27A54F8EB6ed
        );

        bytes32 hns = 0xfb667b5dbbd33e7c0717051928f3b5eb9f4c4de9e1f1c14c71774773504711ca;
        bytes32 wallet = 0x1e3f482b3363eb4710dae2cb2183128e272eafbe137f686851c1caea32502230;
        string memory label = "sp";

        address buyer = 0x91769843CEc84Adcf7A48DF9DBd9694A39f44b42;

        DomainDetails memory details = status.getDomainDetails(buyer, 365, wallet, label);

        console.log("isAvailable", details.isAvailable);
        console.log("labelValid", details.labelValid);
        console.log("owner", details.owner);
        console.log("expiry", details.expiry);
        console.log("isPremium", details.isPremium);
        console.log("reservedAddress", details.reservedAddress);
        console.log("priceInDollars", details.priceInDollars);
        console.log("priceInWei", details.priceInWei);
        console.log("publicRegistrationOpen", details.publicRegistrationOpen);
    }
}

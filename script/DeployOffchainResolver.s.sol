// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import "src/contracts/ccip/OffchainResolver.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        address ens;
        address namewrapper;

        string memory url = "https:/testing.com/{sender}/{data}.json";
        address[] memory signers = new address[](1);
        signers[0] = address(0x1337);

        // ENS_ADDRESS
        // mainnet - 0x253553366Da8546fC250F225fe3d25d0C782303b
        // goerli - 0xCc5e7dB10E65EED1BBD105359e7268aa660f6734
        // sepolia - 0xFED6a969AaA60E4961FCD3EBF1A2e8913ac65B72

        // NAMEWRAPPER_ADDRESS;
        // mainnet - 0xD4416b13d2b3a9aBae7AcD5D6C2BbDBE25686401
        // goerli - 0x114D4603199df73e7D157787f8778E21fCd13066
        // sepolia - 0x0635513f179D50A207757E05759CbD106d7dFcE8

        if (block.chainid == 1) {
            ens = 0x253553366Da8546fC250F225fe3d25d0C782303b;
            namewrapper = 0xD4416b13d2b3a9aBae7AcD5D6C2BbDBE25686401;
        } else if (block.chainid == 5) {
            ens = 0xCc5e7dB10E65EED1BBD105359e7268aa660f6734;
            namewrapper = 0x114D4603199df73e7D157787f8778E21fCd13066;
        } else if (block.chainid == 11155111) {
            ens = 0xFED6a969AaA60E4961FCD3EBF1A2e8913ac65B72;
            namewrapper = 0x0635513f179D50A207757E05759CbD106d7dFcE8;
        } else {
            revert("Unsupported chainid");
        }

        OffchainResolver resolver = new OffchainResolver(url, signers, ens, namewrapper);
        console.log("Deployed OffchainResolver at address: %s", address(resolver));
    }
}

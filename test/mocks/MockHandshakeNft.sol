// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {console} from "forge-std/console.sol";
import {Namehash} from "utils/Namehash.sol";

import "contracts/HandshakeNft.sol";


contract MockHandshakeNft is HandshakeNft {

    constructor() HandshakeNft("test", "test"){
        
    }

    
}
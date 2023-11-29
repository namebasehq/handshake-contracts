pragma solidity ^0.8.18;

import "@op-verifier/OPVerifier.sol";


contract L1OpGateway is OPVerifier {
    constructor(string[] memory urls, address outputOracle) OPVerifier(urls, outputOracle) {}
}



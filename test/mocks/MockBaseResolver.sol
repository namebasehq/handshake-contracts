// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "contracts/resolvers/BaseResolver.sol";
import "contracts/HandshakeNft.sol";

contract MockBaseResolver is BaseResolver {
    constructor(HandshakeNft _tld, HandshakeNft _sld) BaseResolver(_tld, _sld) {}

    function incrementVersionPublicMethod(bytes32 _nodehash) public {
        incrementVersion(_nodehash);
    }

    function incrementVersionPublicAuthorisedMethod(
        bytes32 _nodehash
    ) public authorised(_nodehash) {
        incrementVersion(_nodehash);
    }
}

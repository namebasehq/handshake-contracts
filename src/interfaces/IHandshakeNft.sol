// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "interfaces/ISldRegistrationStrategy.sol";
import "interfaces/IResolver.sol";

interface IHandshakeNft {
    function tokenResolverMap(bytes32) external view returns (IResolver);
}

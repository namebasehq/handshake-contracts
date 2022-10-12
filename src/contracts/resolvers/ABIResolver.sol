// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "interfaces/resolvers/IABIResolver.sol";

import "contracts/resolvers/BaseResolver.sol";

abstract contract ABIResolver is IABIResolver, BaseResolver {
    function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool) {
        return
            _interfaceId == type(IABIResolver).interfaceId || super.supportsInterface(_interfaceId);
    }

    function ABI(bytes32 node, uint256 contentTypes) external view returns (uint256, bytes memory) {
        require(false, "not implemented");
    }
}

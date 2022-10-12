// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "interfaces/resolvers/INameResolver.sol";
import "contracts/resolvers/BaseResolver.sol";

abstract contract NameResolver is INameResolver, BaseResolver {
    function name(bytes32 node) external view returns (string memory) {
        require(false, "not implemented");
    }

    function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool) {
        return
            _interfaceId == type(INameResolver).interfaceId ||
            super.supportsInterface(_interfaceId);
    }
}

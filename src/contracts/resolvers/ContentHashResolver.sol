// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "interfaces/resolvers/IContentHashResolver.sol";
import "contracts/resolvers/BaseResolver.sol";

abstract contract ContentHashResolver is IContentHashResolver, BaseResolver {
    function contenthash(bytes32 node) external view returns (bytes memory) {
        require(false, "not implemented");
    }

    function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool) {
        return
            _interfaceId == type(IContentHashResolver).interfaceId ||
            super.supportsInterface(_interfaceId);
    }
}

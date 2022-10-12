// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "interfaces/resolvers/IInterfaceResolver.sol";
import "contracts/resolvers/BaseResolver.sol";

abstract contract InterfaceResolver is IInterfaceResolver, BaseResolver {
    function interfaceImplementer(bytes32 node, bytes4 interfaceID)
        external
        view
        returns (address)
    {
        require(false, "not implemented");
    }

    function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool) {
        return
            _interfaceId == type(IInterfaceResolver).interfaceId ||
            super.supportsInterface(_interfaceId);
    }
}

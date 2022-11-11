// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "interfaces/resolvers/IInterfaceResolver.sol";
import "contracts/resolvers/BaseResolver.sol";

abstract contract InterfaceResolver is IInterfaceResolver, BaseResolver {
    mapping(uint256 => mapping(bytes32 => mapping(bytes4 => address))) versionable_interfaces;

    function interfaceImplementer(bytes32 node, bytes4 interfaceID)
        external
        view
        returns (address)
    {
        return versionable_interfaces[recordVersions[node]][node][interfaceID];
    }

    /**
     * Sets an interface associated with a name.
     * @param node The node to update.
     * @param interfaceID The EIP 165 interface ID.
     * @param implementer The address of a contract that implements this interface for this node.
     */
    function setInterface(bytes32 node, bytes4 interfaceID, address implementer)
        external
        virtual
        authorised(node)
    {
        versionable_interfaces[recordVersions[node]][node][interfaceID] = implementer;
        emit InterfaceChanged(node, interfaceID, implementer);
    }

    function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool) {
        return
            _interfaceId == type(IInterfaceResolver).interfaceId ||
            super.supportsInterface(_interfaceId);
    }
}

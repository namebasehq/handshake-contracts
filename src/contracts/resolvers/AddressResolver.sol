// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "interfaces/resolvers/IAddressResolver.sol";
import "interfaces/resolvers/IAddrResolver.sol";
import "contracts/resolvers/BaseResolver.sol";

abstract contract AddressResolver is IAddressResolver, IAddrResolver, BaseResolver {
    function addr(bytes32 node, uint256 coinType) public view returns (bytes memory) {
        require(false, "not implemented");
    }

    function addr(bytes32 node) public view returns (address payable) {
        require(false, "not implemented");
    }

    function incrementVersion(bytes32 node) public virtual override authorised(node) {
        address oldAddress = addr(node);

        super.incrementVersion(node);

        address newAddress = addr(node);

        if (newAddress != oldAddress) {
            //maybe we need this
            emit AddrChanged(node, newAddress);
            emit AddressChanged(node, 60, addr(node, 60));
        }
    }

    function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool) {
        return
            _interfaceId == type(IAddressResolver).interfaceId ||
            _interfaceId == type(IAddrResolver).interfaceId ||
            super.supportsInterface(_interfaceId);
    }
}

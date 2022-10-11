// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "contracts/resolvers/BaseResolver.sol";

abstract contract AddressResolver is BaseResolver {
    function supportsInterface(bytes4 _interfaceId) public view override returns (bool) {
        return
            _interfaceId == type(AddressResolver).interfaceId ||
            super.supportsInterface(_interfaceId);
    }
}

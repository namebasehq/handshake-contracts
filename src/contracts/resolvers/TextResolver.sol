// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "interfaces/resolvers/ITextResolver.sol";
import "contracts/resolvers/BaseResolver.sol";

abstract contract TextResolver is ITextResolver, BaseResolver {
    function text(bytes32 node, string calldata key) external view returns (string memory) {
        require(false, "not implemented");
    }

    function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool) {
        return
            _interfaceId == type(ITextResolver).interfaceId ||
            super.supportsInterface(_interfaceId);
    }
}

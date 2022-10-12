// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "contracts/HandshakeNft.sol";
import "interfaces/resolvers/INameResolver.sol";
import "contracts/resolvers/BaseResolver.sol";

abstract contract NameResolver is INameResolver, BaseResolver {
    function name(bytes32 node) external view returns (string memory) {
        string memory domainName = sldContract.name(node);

        if (bytes(domainName).length == 0) {
            domainName = tldContract.name(node);
        }

        return domainName;
    }

    function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool) {
        return
            _interfaceId == type(INameResolver).interfaceId ||
            super.supportsInterface(_interfaceId);
    }
}

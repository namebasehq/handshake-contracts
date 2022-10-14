// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "interfaces/resolvers/IContentHashResolver.sol";
import "contracts/resolvers/BaseResolver.sol";

abstract contract ContentHashResolver is IContentHashResolver, BaseResolver {
    mapping(uint256 => mapping(bytes32 => bytes)) versionable_hashes;

    function contenthash(bytes32 _node) public view returns (bytes memory) {
        return versionable_hashes[recordVersions[_node]][_node];
    }

    function incrementVersion(bytes32 node) public virtual override authorised(node) {
        bytes memory oldHash = contenthash(node);

        super.incrementVersion(node);

        bytes memory newHash = contenthash(node);

        if (keccak256(newHash) != keccak256(oldHash)) {
            emit ContenthashChanged(node, newHash);
        }
    }

    function setContentHash(bytes32 _node, bytes calldata _hash) public authorised(_node) {
        versionable_hashes[recordVersions[_node]][_node] = _hash;
    }

    function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool) {
        return
            _interfaceId == type(IContentHashResolver).interfaceId ||
            super.supportsInterface(_interfaceId);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "interfaces/resolvers/IABIResolver.sol";

import "contracts/resolvers/BaseResolver.sol";

abstract contract ABIResolver is IABIResolver, BaseResolver {
    mapping(uint256 => mapping(bytes32 => mapping(uint256 => bytes))) versionable_abis;

    /**
     * Sets the ABI associated with a node.
     * Nodes may have one ABI of each content type. To remove an ABI, set it to
     * the empty string.
     * @param node The node to update.
     * @param contentType The content type of the ABI
     * @param data The ABI data.
     */
    function setABI(
        bytes32 node,
        uint256 contentType,
        bytes calldata data
    ) external virtual authorised(node) {
        // Content types must be powers of 2
        require(((contentType - 1) & contentType) == 0);

        versionable_abis[recordVersions[node]][node][contentType] = data;
        emit ABIChanged(node, contentType);
    }

    function ABI(bytes32 node, uint256 contentTypes) external view returns (uint256, bytes memory) {
        require(false, "not implemented");
    }

    function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool) {
        return
            _interfaceId == type(IABIResolver).interfaceId || super.supportsInterface(_interfaceId);
    }
}

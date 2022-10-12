// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "interfaces/resolvers/IDNSZoneResolver.sol";
import "interfaces/resolvers/IDNSRecordResolver.sol";
import "contracts/resolvers/BaseResolver.sol";

abstract contract DNSResolver is IDNSRecordResolver, IDNSZoneResolver, BaseResolver {
    // Zone hashes for the domains.
    // A zone hash is an EIP-1577 content hash in binary format that should point to a
    // resource containing a single zonefile.
    // node => contenthash
    mapping(uint256 => mapping(bytes32 => bytes)) private versionable_zonehashes;

    function dnsRecord(
        bytes32 node,
        bytes32 name,
        uint16 resource
    ) external view returns (bytes memory) {
        require(false, "not implemented");
    }

    /**
     * zonehash obtains the hash for the zone.
     * @param node The ENS node to query.
     * @return The associated contenthash.
     */
    function zonehash(bytes32 node) public view virtual override returns (bytes memory) {
        return versionable_zonehashes[recordVersions[node]][node];
    }

    /**
     * setZonehash sets the hash for the zone.
     * May only be called by the owner of that node in the ENS registry.
     * @param node The node to update.
     * @param newHash The zonehash to set
     */
    function setZonehash(bytes32 node, bytes calldata newHash) external virtual authorised(node) {
        uint256 currentRecordVersion = recordVersions[node];
        bytes memory oldHash = versionable_zonehashes[currentRecordVersion][node];
        versionable_zonehashes[currentRecordVersion][node] = newHash;
        emit DNSZonehashChanged(node, oldHash, newHash);
    }

    function incrementVersion(bytes32 node) public virtual override authorised(node) {
        bytes memory oldHash = zonehash(node);

        super.incrementVersion(node);

        bytes memory newHash = zonehash(node);

        if (keccak256(newHash) != keccak256(oldHash)) {
            emit DNSZonehashChanged(node, oldHash, newHash);
        }
    }

    function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool) {
        return
            _interfaceId == type(IDNSRecordResolver).interfaceId ||
            _interfaceId == type(IDNSZoneResolver).interfaceId ||
            super.supportsInterface(_interfaceId);
    }
}

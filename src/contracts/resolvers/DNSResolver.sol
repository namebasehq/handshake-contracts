// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "interfaces/resolvers/IDNSZoneResolver.sol";
import "interfaces/resolvers/IDNSRecordResolver.sol";
import "contracts/resolvers/BaseResolver.sol";

abstract contract DNSResolver is IDNSRecordResolver, IDNSZoneResolver, BaseResolver {
    function dnsRecord(
        bytes32 node,
        bytes32 name,
        uint16 resource
    ) external view returns (bytes memory) {
        require(false, "not implemented");
    }

    function zonehash(bytes32 node) external view returns (bytes memory) {
        require(false, "not implemented");
    }

    function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool) {
        return
            _interfaceId == type(IDNSRecordResolver).interfaceId ||
            _interfaceId == type(IDNSZoneResolver).interfaceId ||
            super.supportsInterface(_interfaceId);
    }
}

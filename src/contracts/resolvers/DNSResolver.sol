// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "interfaces/resolvers/IDNSZoneResolver.sol";
import "interfaces/resolvers/IDNSRecordResolver.sol";
import "contracts/resolvers/BaseResolver.sol";
import "utils/BytesUtils.sol";
import "utils/RRUtils.sol";

abstract contract DNSResolver is IDNSRecordResolver, IDNSZoneResolver, BaseResolver {
    using RRUtils for *;
    using BytesUtils for bytes;

    // Zone hashes for the domains.
    // A zone hash is an EIP-1577 content hash in binary format that should point to a
    // resource containing a single zonefile.
    // node => contenthash
    mapping(uint256 => mapping(bytes32 => bytes)) private versionable_zonehashes;

    // The records themselves.  Stored as binary RRSETs
    // node => version => name => resource => data
    mapping(uint256 => mapping(bytes32 => mapping(bytes32 => mapping(uint16 => bytes))))
        private versionable_records;

    // Count of number of entries for a given name.  Required for DNS resolvers
    // when resolving wildcards.
    // node => version => name => number of records
    mapping(uint256 => mapping(bytes32 => mapping(bytes32 => uint16)))
        private versionable_nameEntriesCount;

    /**
     * Set one or more DNS records.  Records are supplied in wire-format.
     * Records with the same node/name/resource must be supplied one after the
     * other to ensure the data is updated correctly. For example, if the data
     * was supplied:
     *     a.example.com IN A 1.2.3.4
     *     a.example.com IN A 5.6.7.8
     *     www.example.com IN CNAME a.example.com.
     * then this would store the two A records for a.example.com correctly as a
     * single RRSET, however if the data was supplied:
     *     a.example.com IN A 1.2.3.4
     *     www.example.com IN CNAME a.example.com.
     *     a.example.com IN A 5.6.7.8
     * then this would store the first A record, the CNAME, then the second A
     * record which would overwrite the first.
     *
     * @param node the namehash of the node for which to set the records
     * @param data the DNS wire format records to set
     */
    function setDNSRecords(bytes32 node, bytes calldata data) external virtual authorised(node) {
        uint16 resource = 0;
        uint256 offset = 0;
        bytes memory name;
        bytes memory value;

        uint256 version = recordVersions[node];
        // Iterate over the data to add the resource records
        for (RRUtils.RRIterator memory iter = data.iterateRRs(0); !iter.done(); iter.next()) {
            if (resource == 0) {
                resource = iter.dnstype;
                name = iter.name();

                value = bytes(iter.rdata());
            } else {
                bytes memory newName = iter.name();
                if (resource != iter.dnstype || !name.equals(newName)) {
                    setDNSRRSet(
                        node,
                        name,
                        resource,
                        data,
                        offset,
                        iter.offset - offset,
                        value.length == 0,
                        version
                    );
                    resource = iter.dnstype;
                    offset = iter.offset;
                    name = newName;

                    value = bytes(iter.rdata());
                }
            }
        }
        if (name.length > 0) {
            setDNSRRSet(
                node,
                name,
                resource,
                data,
                offset,
                data.length - offset,
                value.length == 0,
                version
            );
        }
    }

    /**
     * Obtain a DNS record.
     * @param node the namehash of the node for which to fetch the record
     * @param name the keccak-256 hash of the fully-qualified name for which to fetch the record
     * @param resource the ID of the resource as per https://en.wikipedia.org/wiki/List_of_DNS_record_types
     * @return the DNS record in wire format if present, otherwise empty
     */
    function dnsRecord(bytes32 node, bytes32 name, uint16 resource)
        public
        view
        virtual
        override
        returns (bytes memory)
    {
        return versionable_records[recordVersions[node]][node][name][resource];
    }

    /**
     * Check if a given node has records.
     * @param node the namehash of the node for which to check the records
     * @param name the namehash of the node for which to check the records
     */
    function hasDNSRecords(bytes32 node, bytes32 name) public view virtual returns (bool) {
        return (versionable_nameEntriesCount[recordVersions[node]][node][name] != 0);
    }

    /**
     * setZonehash sets the hash for the zone.
     * May only be called by the owner of that node.
     * @param _node The node to update.
     * @param _hash The zonehash to set
     */
    function setZonehash(bytes32 _node, bytes calldata _hash) external virtual authorised(_node) {
        uint256 currentRecordVersion = recordVersions[_node];
        bytes memory oldhash = versionable_zonehashes[currentRecordVersion][_node];
        versionable_zonehashes[currentRecordVersion][_node] = _hash;
        emit DNSZonehashChanged(_node, oldhash, _hash);
    }

    /**
     * zonehash obtains the hash for the zone.
     * @param _node The node to query.
     * @return The associated contenthash.
     */
    function zonehash(bytes32 _node) public view virtual override returns (bytes memory) {
        return versionable_zonehashes[recordVersions[_node]][_node];
    }

    function supportsInterface(bytes4 interfaceID) public view virtual override returns (bool) {
        return
            interfaceID == type(IDNSRecordResolver).interfaceId ||
            interfaceID == type(IDNSZoneResolver).interfaceId ||
            super.supportsInterface(interfaceID);
    }

    function setDNSRRSet(
        bytes32 node,
        bytes memory name,
        uint16 resource,
        bytes memory data,
        uint256 offset,
        uint256 size,
        bool deleteRecord,
        uint256 version
    ) private {
        bytes32 nameHash = keccak256(name);
        bytes memory rrData = data.substring(offset, size);
        if (deleteRecord) {
            if (versionable_records[version][node][nameHash][resource].length != 0) {
                versionable_nameEntriesCount[version][node][nameHash]--;
            }
            delete (versionable_records[version][node][nameHash][resource]);
            emit DNSRecordDeleted(node, name, resource);
        } else {
            if (versionable_records[version][node][nameHash][resource].length == 0) {
                unchecked {
                    versionable_nameEntriesCount[version][node][nameHash]++;
                }
            }
            versionable_records[version][node][nameHash][resource] = rrData;
            emit DNSRecordChanged(node, name, resource, rrData);
        }
    }

    function incrementVersion(bytes32 node) public virtual override authorised(node) {
        bytes memory oldHash = zonehash(node);

        super.incrementVersion(node);

        bytes memory newHash = zonehash(node);

        //we can only really track the zonehash to output events not the other
        //dns entries. Just output it if it wasn't blank
        if (keccak256(newHash) != keccak256(oldHash)) {
            emit DNSZonehashChanged(node, oldHash, newHash);
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

interface IDnsResolver {
    //just took this from impervious for now..

    event DnsRecordAdded(bytes32 indexed _namehash, bytes _name, uint16 _resource, bytes _record);
    event DnsRecordChanged(bytes32 indexed _namehash, bytes _name, uint16 _resource, bytes _record);
    event DnsRecordDeleted(bytes32 indexed _namehash, bytes _name, uint16 _resource);
    event DnsZoneCleared(bytes32 indexed _namehash);

    /**
     * Obtain a DNS record.
     * @param _namehash the namehash of the node for which to fetch the record
     * @param _name the keccak-256 hash of the fully-qualified name for which to fetch the record
     * @param _resource the ID of the resource as per https://en.wikipedia.org/wiki/List_of_DNS_record_types
     * @return _ the DNS record in wire format if present, otherwise empty
     */
    function dnsRecord(
        bytes32 _namehash,
        bytes32 _name,
        uint16 _resource
    ) external view returns (bytes memory);

    //need to understand what we do with dnssec public key
    function publickey(bytes32 _namehash) external view returns (bytes32 x, bytes32 y);
}

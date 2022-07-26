// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

interface INameResolver {
    event NameChanged(bytes32 indexed node, string name);

    /**
     * Returns the name associated with a node, for reverse records.
     * Defined in EIP181.
     * @param _namehash The ENS node to query.
     * @return _ The associated name.
     */
    function name(bytes32 _namehash) external view returns (string memory);
}
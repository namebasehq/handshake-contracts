// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

interface IContentHashResolver {
    event ContenthashChanged(bytes32 indexed _namehash, bytes _hash);

    /**
     * Returns the contenthash associated with an ENS node.
     * @param _namehash The ENS node to query.
     * @return _ The associated contenthash.
     */
    function contenthash(bytes32 _namehash) external view returns (bytes memory);
}

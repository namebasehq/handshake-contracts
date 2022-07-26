// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

interface ITextResolver {
    event TextChanged(bytes32 indexed _namehash, string indexed _indexedKey, string key);

    /**
     * Returns the text data associated with an ENS node and key.
     * @param _namehash The ENS node to query.
     * @param _key The text data key to query.
     * @return _ The associated text data.
     */
    function text(bytes32 _namehash, string calldata _key) external view returns (string memory);
}
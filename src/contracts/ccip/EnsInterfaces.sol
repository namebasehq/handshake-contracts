// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title IENS
 * @dev Interface for interaction with the ENS registry
 */
interface IENS {
    /**
     * @dev Returns the owner of the specified node.
     */
    function owner(bytes32 node) external view returns (address);
}

/**
 * @title INameWrapper
 * @dev Interface for interaction with the ENS NameWrapper
 */
interface INameWrapper {
    /**
     * @dev Returns the owner of the specified token ID.
     */
    function ownerOf(uint256 tokenId) external view returns (address);
}

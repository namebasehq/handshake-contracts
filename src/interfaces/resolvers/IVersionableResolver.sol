// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IVersionableResolver {
    event VersionChanged(bytes32 indexed node, uint64 newVersion);

    //cheaper gas using uint256
    function recordVersions(bytes32 node) external view returns (uint256);
}

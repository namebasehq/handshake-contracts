// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// resolver interface based on ENS
// https://github.com/ensdomains/ens-contracts
interface IVersionableResolver {
    event VersionChanged(bytes32 indexed node, uint256 newVersion);

    //cheaper gas using uint256
    function recordVersions(bytes32 node) external view returns (uint256);
}

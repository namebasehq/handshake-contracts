// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// resolver interface based on ENS
// https://github.com/ensdomains/ens-contracts
interface INameResolver {
    event NameChanged(bytes32 indexed node, string name);
    event ReverseClaimed(address indexed _addr, string _domain);

    /**
     * Returns the name associated with an ENS node, for reverse records.
     * Defined in (ENS) EIP181.
     * @param node The node to query.
     * @return The associated name.
     */
    function name(bytes32 node) external view returns (string memory);
}

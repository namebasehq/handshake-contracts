// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

//original interfaces taken from ENS as they seem to be the baseline standard currently
//https://github.com/ensdomains/ens-contracts
interface INameResolver {
    event NameChanged(bytes32 indexed node, string name);

    /**
     * Returns the name associated with an ENS node, for reverse records.
     * Defined in (ENS) EIP181.
     * @param node The node to query.
     * @return The associated name.
     */
    function name(bytes32 node) external view returns (string memory);
}

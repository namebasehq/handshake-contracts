// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;


/**
 * Includes the interface for the legacy (ETH-only) addr function.
 */

//original interfaces taken from ENS as they seem to be the baseline standard currently
//https://github.com/ensdomains/ens-contracts
interface IAddrResolver {
    event AddrChanged(bytes32 indexed node, address a);


    /**
     * Returns the address associated with an ENS node.
     * @param node The node to query.
     * @return The associated address.
     */
    function addr(bytes32 node) external view returns (address payable);
}
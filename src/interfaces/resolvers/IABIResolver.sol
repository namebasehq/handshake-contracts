// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

//original interfaces taken from ENS as they seem to be the baseline standard currently
//https://github.com/ensdomains/ens-contracts
interface IABIResolver {
    event ABIChanged(bytes32 indexed node, uint256 indexed contentType);

    /**
     * Returns the ABI associated with a node.
     * Defined in EIP205.
     * @param node The node to query
     * @param contentTypes A bitwise OR of the ABI formats accepted by the caller.
     * @return contentType The content type of the return value
     * @return data The ABI data
     */
    function ABI(bytes32 node, uint256 contentTypes)
        external
        view
        returns (uint256, bytes memory);
}
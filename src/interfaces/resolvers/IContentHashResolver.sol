// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// resolver interface based on ENS
// https://github.com/ensdomains/ens-contracts
interface IContentHashResolver {
    event ContenthashChanged(bytes32 indexed node, bytes hash);

    /**
     * Returns the contenthash associated with an ENS node.
     * @param node The node to query.
     * @return The associated contenthash.
     */
    function contenthash(bytes32 node) external view returns (bytes memory);
}

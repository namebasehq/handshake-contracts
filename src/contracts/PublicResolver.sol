// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "interfaces/IHandshakeRegistry.sol";
import "ens/resolvers/profiles/ABIResolver.sol";
import "ens/resolvers/profiles/AddrResolver.sol";
import "ens/resolvers/profiles/ContentHashResolver.sol";
import "ens/resolvers/profiles/DNSResolver.sol";
import "ens/resolvers/profiles/InterfaceResolver.sol";
import "ens/resolvers/profiles/NameResolver.sol";
import "ens/resolvers/profiles/PubkeyResolver.sol";
import "ens/resolvers/profiles/TextResolver.sol";
import "ens/resolvers/Multicallable.sol";

contract PublicResolver is
    Multicallable,
    ABIResolver,
    AddrResolver,
    ContentHashResolver,
    DNSResolver,
    InterfaceResolver,
    NameResolver,
    PubkeyResolver,
    TextResolver
{

    IHandshakeRegistry immutable registry;
    address immutable tldContract;
    address immutable sldContract;

    constructor(IHandshakeRegistry _registry, address _tldContract, address _sldContract) {
        registry = _registry;
        tldContract = _tldContract;
        sldContract = _sldContract;
    }

    function isAuthorised(bytes32 node) internal view override returns (bool) {
        if (
            msg.sender == tldContract ||
            msg.sender == sldContract
        ) {
            return true;
        }
        address owner = address(0);
        return owner == msg.sender;
    }

    /**
     * Sets the contenthash associated with a node.
     * May only be called by the owner of that node in the registry.
     * @param node The node to update.
     * @param hash The contenthash to set
     */
    function setContenthash(bytes32 node, bytes calldata hash)
        external
        override (ContentHashResolver)
        authorised(node)
    {
        hashes[node] = hash;
        emit ContenthashChanged(node, hash);
    }

    /**
     * Returns the contenthash associated with a node.
     * @param node The node to query.
     * @return The associated contenthash.
     */
    function contenthash(bytes32 node)
        external
        view
        override (ContentHashResolver)
        returns (bytes memory)
    {
        return hashes[node];
    }

    /**
     * Sets the text data associated with a node and key.
     * May only be called by the owner of that node in the registry.
     * @param node The node to update.
     * @param key The key to set.
     * @param value The text data value to set.
     */
    function setText(
        bytes32 node,
        string calldata key,
        string calldata value
    ) public override (TextResolver) authorised(node) {
        texts[node][key] = value;
        emit TextChanged(node, key, key);
    }

    /**
     * Returns the text data associated with a node and key.
     * @param node The node to query.
     * @param key The text data key to query.
     * @return The associated text data.
     */
    function text(bytes32 node, string calldata key)
        external
        view
        override (TextResolver)
        returns (string memory)
    {
        return texts[node][key];
    }

    function supportsInterface(bytes4 interfaceID)
        public
        view
        override(
            Multicallable,
            ABIResolver,
            AddrResolver,
            ContentHashResolver,
            DNSResolver,
            InterfaceResolver,
            NameResolver,
            PubkeyResolver,
            TextResolver
        )
        returns (bool)
    {
        return super.supportsInterface(interfaceID);
    }

}

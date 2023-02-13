// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "contracts/resolvers/BaseResolver.sol";
import "contracts/HandshakeNft.sol";
import "contracts/resolvers/AddressResolver.sol";
import "contracts/resolvers/ContentHashResolver.sol";
import "contracts/resolvers/DNSResolver.sol";
import "contracts/resolvers/NameResolver.sol";
import "contracts/resolvers/TextResolver.sol";
import "interfaces/IResolver.sol";
import "src/utils/Multicallable.sol";

contract DefaultResolver is
    BaseResolver,
    AddressResolver,
    ContentHashResolver,
    DNSResolver,
    NameResolver,
    TextResolver,
    Multicallable
{
    constructor(HandshakeNft _tld, HandshakeNft _sld) BaseResolver(_tld, _sld) {}

    function supportsInterface(bytes4 _interfaceId)
        public
        view
        override(
            BaseResolver,
            Multicallable,
            AddressResolver,
            ContentHashResolver,
            DNSResolver,
            NameResolver,
            TextResolver
        )
        returns (bool)
    {
        return super.supportsInterface(_interfaceId);
    }

    function incrementVersion(bytes32 node)
        public
        override(BaseResolver, AddressResolver, ContentHashResolver, DNSResolver)
        authorised(node)
    {
        super.incrementVersion(node);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "contracts/resolvers/ABIResolver.sol";
import "contracts/resolvers/AddressResolver.sol";
import "contracts/resolvers/ContentHashResolver.sol";
import "contracts/resolvers/DNSResolver.sol";
import "contracts/resolvers/InterfaceResolver.sol";
import "contracts/resolvers/NameResolver.sol";
import "contracts/resolvers/TextResolver.sol";
import "contracts/resolvers/Multicallable.sol";
import "contracts/resolvers/BaseResolver.sol";
import "contracts/HandshakeNft.sol";

contract TestingABIResolver is ABIResolver {
    constructor(HandshakeNft _tld, HandshakeNft _sld) BaseResolver(_tld, _sld) {}
}

contract TestingContentHashResolver is ContentHashResolver {
    constructor(HandshakeNft _tld, HandshakeNft _sld) BaseResolver(_tld, _sld) {}
}

contract TestingDNSResolver is DNSResolver {
    constructor(HandshakeNft _tld, HandshakeNft _sld) BaseResolver(_tld, _sld) {}
}

contract TestingInterfaceResolver is InterfaceResolver {
    constructor(HandshakeNft _tld, HandshakeNft _sld) BaseResolver(_tld, _sld) {}
}

contract TestingNameResolver is NameResolver {
    constructor(HandshakeNft _tld, HandshakeNft _sld) BaseResolver(_tld, _sld) {}
}

contract TestingTextResolver is TextResolver {
    constructor(HandshakeNft _tld, HandshakeNft _sld) BaseResolver(_tld, _sld) {}
}

contract TestingAddressResolver is AddressResolver {
    constructor(HandshakeNft _tld, HandshakeNft _sld) BaseResolver(_tld, _sld) {}
}

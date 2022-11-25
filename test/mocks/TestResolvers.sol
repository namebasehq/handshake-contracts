// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "contracts/resolvers/AddressResolver.sol";
import "contracts/resolvers/ContentHashResolver.sol";
import "contracts/resolvers/DNSResolver.sol";
import "contracts/resolvers/NameResolver.sol";
import "contracts/resolvers/TextResolver.sol";
import "src/utils/Multicallable.sol";
import "contracts/resolvers/BaseResolver.sol";
import "contracts/HandshakeNft.sol";

contract TestingContentHashResolver is ContentHashResolver {
    constructor(HandshakeNft _tld, HandshakeNft _sld) BaseResolver(_tld, _sld) {}
}

contract TestingDNSResolver is DNSResolver {
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

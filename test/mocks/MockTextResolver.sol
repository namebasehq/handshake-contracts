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

contract MockTextResolver is TextResolver {
    constructor(HandshakeNft _tld, HandshakeNft _sld) BaseResolver(_tld, _sld) {}

    function setText(bytes32 _node, string calldata _key, string calldata _value) public override {
        versionable_texts[0][_node][_key] = _value;
    }
}

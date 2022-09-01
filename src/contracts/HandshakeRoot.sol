// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "interfaces/IHandshakeRegistry.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract HandshakeRoot is Ownable {
    bytes32 private constant ROOT_NODE = bytes32(0);

    bytes4 private constant INTERFACE_META_ID =
        bytes4(keccak256("supportsInterface(bytes4)"));

    event TLDLocked(bytes32 indexed label);

    IHandshakeRegistry public registry;
    mapping(bytes32 => bool) public locked;

    constructor(IHandshakeRegistry _registry) {
        registry = _registry;
    }

    function setSubnodeOwner(bytes32 label, address owner)
        external
        onlyOwner
    {
        require(!locked[label]);
        registry.setSubnodeOwner(ROOT_NODE, label, owner);
    }

    function setResolver(address resolver) external onlyOwner {
        registry.setResolver(ROOT_NODE, resolver);
    }

    function lock(bytes32 label) external onlyOwner {
        emit TLDLocked(label);
        locked[label] = true;
    }

    function supportsInterface(bytes4 interfaceID)
        external
        pure
        returns (bool)
    {
        return interfaceID == INTERFACE_META_ID;
    }
}

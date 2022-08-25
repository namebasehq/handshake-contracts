// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "interfaces/IAddressResolver.sol";
import "interfaces/IContentHashResolver.sol";
import "interfaces/ITextResolver.sol";
import "interfaces/IDnsResolver.sol";
import "interfaces/INameResolver.sol";

interface IResolver is
    IAddressResolver,
    IContentHashResolver,
    ITextResolver,
    IDnsResolver,
    INameResolver
{
    function setAddr(bytes32 _namehash, address addr) external;

    function setContentHash(bytes32 _namehash, bytes calldata hash) external;

    function setName(bytes32 _namehash, string calldata _name) external;

    function setPublicKey(
        bytes32 _namehash,
        bytes32 x,
        bytes32 y
    ) external;

    function setText(
        bytes32 _namehash,
        string calldata key,
        string calldata value
    ) external;

    function setDnsRecord(
        bytes32 _namehash,
        bytes32 _name,
        uint16 _resource
    ) external returns (bytes memory);
}

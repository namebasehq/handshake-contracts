// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "interfaces/data/IAddressResolver.sol";
import "interfaces/data/IContentHashResolver.sol";
import "interfaces/data/ITextResolver.sol";
import "interfaces/data/IDnsResolver.sol";
import "interfaces/data/INameResolver.sol";


interface IResolver is IAddressResolver, IContentHashResolver, ITextResolver, IDnsResolver, INameResolver {

    function setAddr(bytes32 _namehash, address addr) external;
    function setContenthash(bytes32 _namehash, bytes calldata hash) external;
    function setName(bytes32 _namehash, string calldata _name) external;
    function setPubkey(bytes32 _namehash, bytes32 x, bytes32 y) external;
    function setText(bytes32 _namehash, string calldata key, string calldata value) external;

}

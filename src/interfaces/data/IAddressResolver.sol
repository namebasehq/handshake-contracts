// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;


interface IAddressResolver {

    event AddrChanged(bytes32 indexed _namehash, address _addr);
    function addr(bytes32 _namehash) external view returns (address payable);
}
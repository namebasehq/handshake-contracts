// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

interface IAddressResolver {
    event AddrChanged(bytes32 indexed _namehash, address _addr);

    /**
     * Allows a user to commit intent to register an SLD
     * @param _namehash The namehash of the domain
     * @return _ returns back mapped address on the native chain
     */
    function addr(bytes32 _namehash) external view returns (address payable);
}

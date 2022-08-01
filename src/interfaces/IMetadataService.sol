// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

interface IMetadataService {

function tokenURI(bytes32 _namehash) external view returns (string memory);
}
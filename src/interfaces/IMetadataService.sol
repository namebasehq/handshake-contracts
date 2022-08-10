// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface IMetadataService is IERC165 {
    function tokenURI(bytes32 _namehash) external view returns (string memory);
}

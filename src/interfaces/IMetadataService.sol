// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface IMetadataService is IERC165 {
    function tokenURI(bytes32 _namehash) external view returns (string memory);
}

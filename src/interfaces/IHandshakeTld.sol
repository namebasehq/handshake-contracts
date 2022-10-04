// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "interfaces/ITldClaimManager.sol";

interface IHandshakeTld {
    function register(address _addr, string calldata _domain) external;

    function ownerOf(uint256 _id) external view returns (address);

    function isApprovedOrOwner(address _operator, uint256 _id) external view returns (bool);

    function setTldClaimManager(ITldClaimManager _manager) external;

    function namehashToLabelMap(bytes32 _namehash) external view returns (string memory);
}

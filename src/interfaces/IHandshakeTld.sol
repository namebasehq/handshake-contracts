// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "interfaces/ITldClaimManager.sol";
import "interfaces/IResolver.sol";

interface IHandshakeTld {
    //function register(address _addr, string calldata _domain) external;

    function registerWithResolver(address _addr, string calldata _domain, IResolver _resolver) external;

    function ownerOf(uint256 _id) external view returns (address);

    function isApprovedOrOwner(address _operator, uint256 _id) external view returns (bool);

    function setTldClaimManager(ITldClaimManager _manager) external;

    function namehashToLabelMap(bytes32 _namehash) external view returns (string memory);

    function setResolver(bytes32 _namehash, IResolver _resolver) external;
}

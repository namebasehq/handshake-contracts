// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

interface ITldClaimManager {
    function canClaim(address _addr, bytes32 _namehash, bytes32[] memory _proofs) external view returns (bool);
    function claimTld(address _addr, bytes32 _namehash, bytes32[] memory _proofs) external;
    function setMerkleRoot(bytes32 _root) external;
    function MerkleRoot() external returns (bytes32);
}
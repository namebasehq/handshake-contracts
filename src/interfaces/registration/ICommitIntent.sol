// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

interface ICommitIntent {
    function updateMaxBlockWaitForCommit(uint256 _maxBlockWait) external;
    function commitIntent(bytes32 _namehash) external;
    function multiCommitIntent(bytes32[] calldata _namehash) external;
    function allowedCommit(bytes32 _namehash, address _addr) external view returns (bool);
    function MaxBlockWaitForCommit() external view returns (uint256);    
}
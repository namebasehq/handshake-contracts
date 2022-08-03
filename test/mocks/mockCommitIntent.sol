// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;


import "interfaces/ICommitIntent.sol";


contract MockCommitIntent is ICommitIntent {

    bool private Allowed;
    uint256 private MaxBlocks;

    constructor(bool _allowed){
        Allowed = _allowed;
    }


    function updateMaxBlockWaitForCommit(uint256 _maxBlockWait) external{
        MaxBlocks = _maxBlockWait;
    }

    function commitIntent(bytes32 _namehash) external{

    }

    function multiCommitIntent(bytes32[] calldata _namehash) external{

    }


    function allowedCommit(bytes32 _namehash, bytes32 _secret, address _addr) external view returns (bool){
        return Allowed;
    }

    function MaxBlockWaitForCommit() external view returns (uint256){
        return MaxBlocks;
    }



}
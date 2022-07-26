// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "interfaces/registration/ICommitIntent.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SldCommitIntent is ICommitIntent, Ownable {

    struct CommitData{
        uint96 blockNumber;     // 96
        address user;            // 160
                                 // 1x 256 bit slots
    }


    mapping(bytes32 => CommitData) private NodeIntentBlockNumber;

    uint256 public MaxBlockWaitForCommit = 30;

    constructor(){

    }

    function commitIntent(bytes32 _combinedHash) public {
        require(NodeIntentBlockNumber[_combinedHash].blockNumber < block.number, "already been committed");
        CommitData memory data = CommitData(uint96(block.number + MaxBlockWaitForCommit), msg.sender);
         NodeIntentBlockNumber[_combinedHash] = data;
    }

    function allowedCommit(bytes32 _namehash, bytes32 _secret, address _addr) external view returns (bool){
        bytes32 combinedHash = keccak256(abi.encodePacked(_namehash, _addr, _secret));
        CommitData memory data = NodeIntentBlockNumber[combinedHash];
        return data.blockNumber > block.number && data.user == _addr;
    }

    function updateMaxBlockWaitForCommit(uint256 _maxBlockWait) external onlyOwner {
        MaxBlockWaitForCommit = _maxBlockWait;
    }

    function multiCommitIntent(bytes32[] calldata _combinedHashes) external {
        
        //cache length of array to reduce reads
        uint256 hashLength = _combinedHashes.length;

        for(uint256 i; i < hashLength;){

            commitIntent(_combinedHashes[i]);
            
            //most gas efficient way of looping
            unchecked { ++i; }
        }
    }
}
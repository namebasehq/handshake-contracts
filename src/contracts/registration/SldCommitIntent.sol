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

    function commitIntent(bytes32 _namehash) external {
        require(NodeIntentBlockNumber[_namehash].blockNumber < block.number, "already been committed");
        CommitData memory data = CommitData(uint32(block.number + MaxBlockWaitForCommit), msg.sender);
         NodeIntentBlockNumber[_namehash] = data;
    }

    function allowedCommit(bytes32 _namehash, address _addr) external view returns (bool){
        CommitData memory data = NodeIntentBlockNumber[_namehash];
        return data.blockNumber > block.number && data.user == _addr;
    }

    function updateMaxBlockWaitForCommit(uint256 _maxBlockWait) external onlyOwner {
        MaxBlockWaitForCommit = _maxBlockWait;
    }
}
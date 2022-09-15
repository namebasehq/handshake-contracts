// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "interfaces/ICommitIntent.sol";
import "interfaces/ILabelValidator.sol";
import "contracts/LabelValidator.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SldCommitIntent is ICommitIntent, Ownable {
    struct CommitData {
        uint96 blockNumber; // 96
        address user; // 160
        // 1x 256 bit slots
    }

    mapping(bytes32 => CommitData) private nodeIntentBlockNumber;

    uint256 public maxBlockWaitForCommit = 30;
    uint256 public minBlockWaitForCommit = 3;

    constructor() {}

    function commitIntent(bytes32 _combinedHash) public {
        require(
            nodeIntentBlockNumber[_combinedHash].blockNumber < block.number,
            "already been committed"
        );
        CommitData memory data = CommitData(
            uint96(block.number + maxBlockWaitForCommit),
            msg.sender
        );
        nodeIntentBlockNumber[_combinedHash] = data;
    }

    function allowedCommit(
        bytes32 _namehash,
        bytes32 _secret,
        address _addr
    ) external view returns (bool) {
        bytes32 combinedHash = keccak256(abi.encodePacked(_namehash, _secret, _addr));
        CommitData memory data = nodeIntentBlockNumber[combinedHash];

        return
            data.blockNumber > (block.number + minBlockWaitForCommit) &&
            (data.blockNumber - maxBlockWaitForCommit + minBlockWaitForCommit) <= //min time to wait
            block.number &&
            data.user == _addr;
    }

    function updateMaxBlockWaitForCommit(uint256 _maxBlockWait) external onlyOwner {
        maxBlockWaitForCommit = _maxBlockWait;
    }

    function updateMinBlockWaitForCommit(uint256 _minBlockWait) external onlyOwner {
        minBlockWaitForCommit = _minBlockWait;
    }

    function multiCommitIntent(bytes32[] calldata _combinedHashes) external {
        //cache length of array to reduce reads
        uint256 hashLength = _combinedHashes.length;

        for (uint256 i; i < hashLength; ) {
            commitIntent(_combinedHashes[i]);

            //most gas efficient way of looping
            unchecked {
                ++i;
            }
        }
    }
}

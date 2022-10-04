// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "interfaces/ICommitIntent.sol";
import "interfaces/ILabelValidator.sol";
import "contracts/LabelValidator.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Subdomain intent to register
 * @author Sam Ward
 * @notice This contract is for registering intent to register a subdomain
 */
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

    /**
     * @notice Save commit intent hash
     * @dev This function can called by anyone and will save the hash of data that
     *      can be used to verify that the user intends to register the domain
     *      this is so the user isn't front run
     * @param _combinedHash keccak256 hash of sld namehash / bytes32 secret / msg.sender
     */
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

    /**
     * @notice Update max block wait time for commit
     * @dev Only the contract owner can call this function
     * @param _maxBlockWait Number of blocks until the commit expires
     */
    function updateMaxBlockWaitForCommit(uint256 _maxBlockWait) external onlyOwner {
        maxBlockWaitForCommit = _maxBlockWait;
    }

    /**
     * @notice Update min block wait time for commit
     * @dev Only the contract owner can call this function. This helps prevent front running
     *      and also prevents issues if there is a reorg (unlikely)
     * @param _minBlockWait Number of blocks until the commit becomes active
     */
    function updateMinBlockWaitForCommit(uint256 _minBlockWait) external onlyOwner {
        minBlockWaitForCommit = _minBlockWait;
    }

    /**
     * @notice Save multiple commit intent hash
     * @dev This function can called by anyone and will save the hash of data that
     *      can be used to verify that the user intends to register the domain
     *      this is so the user isn't front run
     * @param _combinedHashes array of keccak256 hashes of sld namehash / bytes32 secret / msg.sender
     */
    function multiCommitIntent(bytes32[] calldata _combinedHashes) external {
        for (uint256 i; i < _combinedHashes.length; ) {
            commitIntent(_combinedHashes[i]);

            //most gas efficient way of looping
            unchecked {
                ++i;
            }
        }
    }
}

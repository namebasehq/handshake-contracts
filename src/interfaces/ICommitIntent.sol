// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

interface ICommitIntent {

    /**
     * Allows the owner of the contract to set the max wait in blocks
     * for registration of an SLD. While this is active no other wallet
     * can commit intent to register the SLD.
     * @param _maxBlockWait The maximum number of blocks to wait.
     */
    function updateMaxBlockWaitForCommit(uint256 _maxBlockWait) external;

     /**
     * Allows a user to commit intent to register an SLD
     * @param _namehash The namehash of the SLD that the user intends to register
     */
    function commitIntent(bytes32 _namehash) external;

    /**
     * Allows a user to commit intent to register multiple SLDs
     * @param _namehash The namehash(s) of the SLDs that the user intends to register
     */
    function multiCommitIntent(bytes32[] calldata _namehash) external;

    /**
     * Allows a user to commit intent to register multiple SLDs
     * @param _namehash The namehash(s) of the SLDs that the user intends to register
     * @param _addr the address of the user
     *
     * @return _ True/False value if the user is currently allowed to register the name
     */
    function allowedCommit(bytes32 _namehash, bytes32 _secret, address _addr) external view returns (bool);

    /**
     * Max time in blocks that an SLD is held for.
     * @return _ uint256 number of blocks, probably set to 5760 or something like that << approx 24 hours
     */
    function MaxBlockWaitForCommit() external view returns (uint256);    


}
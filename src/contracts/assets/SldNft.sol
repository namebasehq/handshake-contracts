// SPDX-License-Identifier: UNLICENSED

import "src/contracts/assets/HandshakeERC721.sol";
import "src/contracts/assets/TldNft.sol";
import "src/contracts/registration/SldCommitIntent.sol";



pragma solidity ^0.8.15;

contract SldNft is HandshakeERC721 {


    TldNft public TldNftContract;
    SldCommitIntent public CommitIntent;

     mapping(bytes32 => bytes32) private NamehashToParentMap;


    constructor() HandshakeERC721("HSLD", "Handshake Second Level Domain"){
        TldNftContract = new TldNft();
        TldNftContract.transferOwnership(msg.sender);

        CommitIntent = new SldCommitIntent();
        CommitIntent.transferOwnership(msg.sender);       
    }

    function purchaseSld(string calldata _label, bytes32 _secret, uint256 _registrationLength, bytes32 _parentNamehash) public {
        bytes32 namehash;
        uint256 id;
        require(CommitIntent.allowedCommit(namehash, _secret, msg.sender), "commit not allowed");

        _safeMint(msg.sender, id);
    }


}
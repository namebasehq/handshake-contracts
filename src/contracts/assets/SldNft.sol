// SPDX-License-Identifier: UNLICENSED

import "src/contracts/assets/HandshakeERC721.sol";
import "src/contracts/assets/TldNft.sol";


pragma solidity ^0.8.15;

contract SldNft is HandshakeERC721 {


    TldNft public TldNftContract;


    constructor() HandshakeERC721("HSLD", "Handshake Second Level Domain"){
        TldNftContract = new TldNft();
        TldNftContract.transferOwnership(msg.sender);

        
    }

    function purchaseSld(string calldata _label, uint256 _registrationLength, uint256 _parentId) public {

    }


}
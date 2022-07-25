
// SPDX-License-Identifier: UNLICENSED

import "solmate/src/tokens/ERC721.sol"; //more gas efficient than OpenZeppelin
import "interfaces/data/IMetadataService.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity ^0.8.15;

abstract contract HandshakeERC721 is ERC721, Ownable {

    IMetadataService public Metadata;

        constructor(string memory _symbol, string memory _name) ERC721(_symbol, _name){

    }

    function tokenURI(uint256 _id) public view override returns (string memory){
        require(false, "not implemented");
        return Metadata.tokenURI(bytes32(_id));
    }

    function setMetadataContract(IMetadataService _metadata) external onlyOwner {
        Metadata = _metadata;
    }

}
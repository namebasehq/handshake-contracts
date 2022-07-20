// SPDX-License-Identifier: UNLICENSED

import "solmate/src/tokens/ERC721.sol"; //more gas efficient than OpenZeppelin
import "interfaces/data/IMetadataService.sol";
import "interfaces/registration/ITldClaimManager.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity ^0.8.15;

contract TldNft is ERC721, Ownable {

        IMetadataService public Metadata;
        ITldClaimManager public ClaimManager;

    constructor() ERC721("HTLD", "Handshake Top Level Domain"){

    }

    function setTldClaimManager(ITldClaimManager _manager) public onlyOwner {
        ClaimManager = _manager;
    }

    function mint(address _addr, bytes32 _namehash) external {
        require(address(ClaimManager) == msg.sender, "not authorised");
        _safeMint(_addr, uint256(_namehash));
    }

    function tokenURI(uint256 _id) public view override returns (string memory){
        require(false, "not implemented");
        return Metadata.tokenURI(bytes32(_id));
    }

}
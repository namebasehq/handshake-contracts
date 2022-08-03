// SPDX-License-Identifier: UNLICENSED

import "solmate/src/tokens/ERC721.sol"; //more gas efficient than OpenZeppelin
import "interfaces/IMetadataService.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity ^0.8.15;

//this is the base class for both SLD and TLD NFTs
abstract contract HandshakeERC721 is ERC721, Ownable {
    mapping(bytes32 => string) public NamehashToLabelMap;

    IMetadataService public Metadata;

    constructor(string memory _symbol, string memory _name) ERC721(_symbol, _name) {}

    function tokenURI(uint256 _id) public view override returns (string memory) {
        require(false, "not implemented");
        return Metadata.tokenURI(bytes32(_id));
    }

    function setMetadataContract(IMetadataService _metadata) external onlyOwner {
        Metadata = _metadata;
    }

    function getNamehash(string calldata _label, bytes32 _parentHash)
        internal
        pure
        returns (bytes32)
    {
        bytes32 encoded_label = keccak256(abi.encodePacked(_label));
        bytes32 big_hash = keccak256(abi.encodePacked(_parentHash, encoded_label));

        return big_hash;
    }

    modifier isApprovedOrOwner(uint256 _id) {
        address owner = ownerOf(_id);
        require(
            owner == msg.sender ||
                isApprovedForAll[owner][msg.sender] ||
                getApproved[_id] == msg.sender,
            "Not approved or owner"
        );

        _;
    }
}

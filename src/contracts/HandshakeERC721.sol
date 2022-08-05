// SPDX-License-Identifier: UNLICENSED

import "solmate/src/tokens/ERC721.sol"; //more gas efficient than OpenZeppelin
import "interfaces/IMetadataService.sol";
import "interfaces/ISldPriceStrategy.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

pragma solidity ^0.8.15;

//this is the base class for both SLD and TLD NFTs
abstract contract HandshakeERC721 is ERC721, Ownable {
    using ERC165Checker for address;

    //token uri for metadata service uses namehash as the input value
    bytes4 private constant TOKEN_URI_SELECTOR = bytes4(keccak256("tokenURI(bytes32)"));

    mapping(bytes32 => string) public NamehashToLabelMap;

    //moved this from tld contract so we can have subdomains of subdomains.
    mapping(bytes32 => ISldPriceStrategy) public SldDefaultPriceStrategy;

    IMetadataService public Metadata;

    constructor(string memory _symbol, string memory _name) ERC721(_symbol, _name) {}

    function tokenURI(uint256 _id) public view override returns (string memory) {
        require(address(Metadata) != address(0), "Metadata service is not implemented");
        return Metadata.tokenURI(bytes32(_id));
    }

    function setMetadataContract(IMetadataService _metadata) external onlyOwner {
        require(
            address(_metadata).supportsInterface(TOKEN_URI_SELECTOR),
            "does not implement tokenUri method"
        );
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

    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        virtual
        returns (address receiver, uint256 royaltyAmount)
    {}

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return
            super.supportsInterface(interfaceId) ||
            interfaceId == this.royaltyInfo.selector ^ this.tokenURI.selector;
    }

    function isApproved(uint256 _id) public view returns (bool) {
        if (_ownerOf[_id] == address(0)) return false;
        address owner = ownerOf(_id);
        return
            owner == msg.sender ||
            isApprovedForAll[owner][msg.sender] ||
            getApproved[_id] == msg.sender;
    }

    modifier isApprovedOrOwner(uint256 _id) {
        require(isApproved(_id), "Not approved or owner");
        _;
    }
}

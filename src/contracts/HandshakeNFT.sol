// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "solmate/tokens/ERC721.sol"; //more gas efficient than OpenZeppelin
import "interfaces/IHandshakeRegistry.sol";
import "interfaces/IMetadataService.sol";
import "interfaces/ISldRegistrationStrategy.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

// base class for both SLD and TLDs
abstract contract HandshakeNFT is ERC721, Ownable {
    using ERC165Checker for address;

    // token uri for metadata service uses namehash as the input value
    bytes4 private constant TOKEN_URI_SELECTOR = bytes4(keccak256("tokenURI(bytes32)"));
    
    // a map of string labels
    mapping(bytes32 => string) public NamehashToLabelMap;

    IHandshakeRegistry public registry;
    IMetadataService public Metadata;

    constructor(IHandshakeRegistry _registry, string memory _symbol, string memory _name) ERC721(_symbol, _name) {
        registry = _registry;
    }

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

    // /**
    //  * @dev Gets the owner of the specified token ID. Names become unowned
    //  *      when their registration expires.
    //  * @param tokenId uint256 ID of the token to query the owner of
    //  * @return address currently marked as the owner of the given token ID
    //  */
    // function ownerOf(uint256 tokenId)
    //     public
    //     view
    //     override(IERC721, ERC721)
    //     returns (address)
    // {
    //     require(expiries[tokenId] > block.timestamp);
    //     return super.ownerOf(tokenId);
    // }

    // /**
    //  * v2.1.3 version of _isApprovedOrOwner which calls ownerOf(tokenId) and takes grace period into consideration instead of ERC721.ownerOf(tokenId);
    //  * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v2.1.3/contracts/token/ERC721/ERC721.sol#L187
    //  * @dev Returns whether the given spender can transfer a given token ID
    //  * @param spender address of the spender to query
    //  * @param tokenId uint256 ID of the token to be transferred
    //  * @return bool whether the msg.sender is approved for the given token ID,
    //  *    is an operator of the owner, or is the owner of the token
    //  */
    // function _isApprovedOrOwner(address spender, uint256 tokenId)
    //     internal
    //     view
    //     override
    //     returns (bool)
    // {
    //     address owner = ownerOf(tokenId);
    //     return (spender == owner ||
    //         getApproved(tokenId) == spender ||
    //         isApprovedForAll(owner, spender));
    // }

    function isApproved(uint256 _id, address _operator) public view returns (bool) {
        if (_ownerOf[_id] == address(0)) return false;

        address owner = ownerOf(_id);
        return
            owner == _operator ||
            isApprovedForAll[owner][_operator] ||
            getApproved[_id] == _operator;
    }

    function exists(uint256 _id) public view returns (bool) {
        return _ownerOf[_id] != address(0);
    }

    modifier isApprovedOrOwner(uint256 _id) {
        require(isApproved(_id, msg.sender), "Not approved or owner");
        _;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {console} from "forge-std/console.sol";
import {Namehash} from "utils/Namehash.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "interfaces/IMetadataService.sol";
import "interfaces/ISldRegistrationStrategy.sol";

// base class for both SLD and TLDs
abstract contract HandshakeNft is ERC721, Ownable {
    using ERC165Checker for address;

    // token uri for metadata service uses namehash as the input value
    bytes4 private constant TOKEN_URI_SELECTOR = bytes4(keccak256("tokenURI(bytes32)"));

    // a map of string labels
    mapping(bytes32 => string) public namehashToLabelMap;

    IMetadataService public metadata;

    constructor(string memory _symbol, string memory _name) ERC721(_symbol, _name) {}

    function tokenURI(uint256 _id) public view override returns (string memory) {
        require(address(metadata) != address(0), "Metadata service is not implemented");
        return metadata.tokenURI(bytes32(_id));
    }

    function setMetadataContract(IMetadataService _metadata) external onlyOwner {
        require(
            address(_metadata).supportsInterface(TOKEN_URI_SELECTOR),
            "does not implement tokenUri method"
        );
        metadata = _metadata;
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return super.supportsInterface(interfaceId) || interfaceId == this.tokenURI.selector;
    }

    /**
     * @dev Gets the owner of the specified token ID. Names become unowned when their registration expires.
     * @param tokenId uint256 ID of the token to query the owner of
     * @return address currently marked as the owner of the given token ID
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        // TODO: implement expirations
        // require(expiries[tokenId] > block.timestamp);
        console.log("ownerOf");
        console.log(tokenId);
        return super.ownerOf(tokenId);
    }

    /**
     * custom version of _isApprovedOrOwner which calls ownerOf(tokenId) and takes expiration into consideration instead of ERC721.ownerOf(tokenId);
     * @param spender address of the spender to query
     * @param tokenId uint256 ID of the token to be transferred
     * @return bool whether spender is approved for the given token ID, is an operator of the owner, or is the owner of the token
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId)
        internal
        view
        override
        returns (bool)
    {
        address owner = ownerOf(tokenId);
        return (spender == owner ||
            getApproved(tokenId) == spender ||
            isApprovedForAll(owner, spender));
    }

    /**
     * public version of _isApprovedOrOwner which calls ownerOf(tokenId) and takes expiration into consideration instead of ERC721.ownerOf(tokenId);
     * @param spender address of the spender to query
     * @param tokenId uint256 ID of the token to be transferred
     * @return bool whether the spender is approved for the given token ID, is an operator of the owner, or is the owner of the token
     */
    function isApprovedOrOwner(address spender, uint256 tokenId)
        public
        view
        virtual
        returns (bool)
    {
        return _isApprovedOrOwner(spender, tokenId);
    }

    /**
     * modifier version of _isApprovedOrOwner which calls ownerOf(tokenId) and takes expiration into consideration instead of ERC721.ownerOf(tokenId);
     * @param tokenId uint256 ID of the token to be transferred
     */
    modifier onlyApprovedOrOwner(uint256 tokenId) {
        require(_isApprovedOrOwner(msg.sender, tokenId), "not approved or owner");
        _;
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function exists(uint256 tokenId) public view returns (bool) {
        return ERC721._exists(tokenId);
    }
}

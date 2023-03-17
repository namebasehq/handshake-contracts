// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "interfaces/IMetadataService.sol";
import "interfaces/IResolver.sol";

// base class for both SLD and TLDs
abstract contract HandshakeNft is ERC721, Ownable {
    using ERC165Checker for address;

    // token uri for metadata service uses namehash as the input value
    bytes4 private constant TOKEN_URI_SELECTOR = bytes4(keccak256("tokenURI(bytes32)"));

    mapping(bytes32 => IResolver) public tokenResolverMap;

    IResolver defaultResolver;

    IMetadataService public metadata;

    error TokenUriNotImplemented();
    error NotApprovedOrOwner();
    error InvalidAddress();
    error RoyaltyAmountTooHigh();
    error NotRegistrationManager();

    constructor(string memory _symbol, string memory _name) ERC721(_symbol, _name) {}

    function tokenURI(uint256 _id) public view override returns (string memory) {
        return metadata.tokenURI(bytes32(_id));
    }

    function setMetadataContract(IMetadataService _metadata) external onlyOwner {
        if (!address(_metadata).supportsInterface(TOKEN_URI_SELECTOR)) {
            revert TokenUriNotImplemented();
        }

        metadata = _metadata;
    }

    function setDefaultResolver(IResolver _resolver) external onlyOwner {
        defaultResolver = _resolver;
    }

    function setResolver(bytes32 _namehash, IResolver _resolver)
        public
        virtual
        onlyApprovedOrOwner(uint256(_namehash))
    {
        tokenResolverMap[_namehash] = _resolver;
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return super.supportsInterface(interfaceId) || interfaceId == this.tokenURI.selector;
    }

    /**
     * @dev Gets the owner of the specified token ID. Names become unowned when their registration expires.
     * @param tokenId uint256 ID of the token to query the owner of
     * @return address currently marked as the owner of the given token ID
     */
    function ownerOf(uint256 tokenId) public view virtual override(ERC721) returns (address) {
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
        if (_exists(tokenId)) {
            address owner = ownerOf(tokenId);

            return (spender == owner ||
                isApprovedForAll(owner, spender) ||
                getApproved(tokenId) == spender);
        } else {
            return false;
        }
    }

    /**
     * @notice public version of _isApprovedOrOwner which calls ownerOf(tokenId) and takes expiration into consideration instead of ERC721.ownerOf(tokenId);
     * @param spender address of the spender to query
     * @param tokenId uint256 ID of the token to be transferred
     *
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
     * @notice returns back the string representation of the name. It makes more sense to have it here than on the resolver as the resolver
     *         can be updated and we will likely use the name string in the metadata class
     * @dev should override this function in the inherited class
     * @param _namehash bytes32 representaion of the domain
     *
     * @return _name fully qualified name of the domain / NFT
     */
    function name(bytes32 _namehash) external view virtual returns (string memory _name) {}

    function parent(bytes32 _namehash) external view virtual returns (string memory _parentName) {}

    function expiry(bytes32 _namehash) external view virtual returns (uint256 _expiry) {}

    /**
     * @notice modifier version of _isApprovedOrOwner which calls ownerOf(tokenId) and takes expiration into consideration instead of ERC721.ownerOf(tokenId);
     * @param tokenId uint256 ID of the token to be transferred
     */
    modifier onlyApprovedOrOwner(uint256 tokenId) {
        if (!isApprovedOrOwner(msg.sender, tokenId)) {
            revert NotApprovedOrOwner();
        }
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
    function exists(uint256 tokenId) public view virtual returns (bool) {
        return ERC721._exists(tokenId);
    }
}

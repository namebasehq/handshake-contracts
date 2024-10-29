// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@ensdomains/ens-contracts/contracts/registry/ENS.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "forge-std/console.sol";

contract MockENS is ENS {
    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    constructor() {}

    // IERC721 functions
    function balanceOf(address owner) public view returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }

    function approve(address to, uint256 tokenId) public {
        address owner = ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");
        require(
            msg.sender == owner || isApprovedForAll(owner, msg.sender),
            "ERC721: approve caller is not owner nor approved for all"
        );
        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    function getApproved(uint256 tokenId) public view returns (address) {
        require(_owners[tokenId] != address(0), "ERC721: approved query for nonexistent token");
        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) public override {
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address owner, address operator) public view override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function transferFrom(address from, address to, uint256 tokenId) public {
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: transfer caller is not owner nor approved");
        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;
        emit Transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public {
        transferFrom(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public {
        safeTransferFrom(from, to, tokenId, "");
    }

    // ENS functions
    function owner(bytes32 node) public view override returns (address) {
        console.log("owner called");
        return ownerOf(uint256(node));
    }

    function register(bytes32 node, address nodeOwner) external {
        uint256 tokenId = uint256(node);
        _owners[tokenId] = nodeOwner;
        _balances[nodeOwner] += 1;
        emit Transfer(address(0), nodeOwner, tokenId);
    }

    // Additional functions as per ENS.sol...
    function setResolver(bytes32 node, address resolver) external override {
        revert("Not implemented");
    }
<<<<<<< HEAD

    function ttl(bytes32 node) external view override returns (uint64) {
        revert("Not implemented");
    }

    function resolver(bytes32 node) external view override returns (address) {
        revert("Not implemented");
    }
    // Continue implementing other necessary functions

    function supportsInterface(bytes4 interfaceId) public view returns (bool) {
        return interfaceId == type(IERC721).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    function setRecord(bytes32 node, address nodeOwner, address resolver, uint64 ttl) external override {
=======
    function ttl(bytes32 node) external view override returns (uint64) {
        revert("Not implemented");
    }
    function resolver(bytes32 node) external view override returns (address) {
        revert("Not implemented");
    }
    // Continue implementing other necessary functions

    function supportsInterface(bytes4 interfaceId) public view returns (bool) {
        return interfaceId == type(IERC721).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    function setRecord(
        bytes32 node,
        address nodeOwner,
        address resolver,
        uint64 ttl
    ) external override {
>>>>>>> main
        // Simple logic or revert
        revert("Not implemented yet");
    }

<<<<<<< HEAD
    function setSubnodeOwner(bytes32 node, bytes32 label, address nodeOwner) external override returns (bytes32) {
=======
    function setSubnodeOwner(
        bytes32 node,
        bytes32 label,
        address nodeOwner
    ) external override returns (bytes32) {
>>>>>>> main
        // Return label to simulate creation of subnode
        return label;
    }

    function recordExists(bytes32 node) external view override returns (bool) {
        // Check if owner exists
        return _owners[uint256(node)] != address(0);
    }

<<<<<<< HEAD
    function setSubnodeRecord(bytes32 node, bytes32 label, address nodeOwner, address resolver, uint64 ttl)
        external
        override
    {
=======
    function setSubnodeRecord(
        bytes32 node,
        bytes32 label,
        address nodeOwner,
        address resolver,
        uint64 ttl
    ) external override {
>>>>>>> main
        // Simple logic or revert to simulate setting a subnode record
        revert("Not implemented yet");
    }

    function setOwner(bytes32 node, address nodeOwner) external override {
        // Simple logic or revert to simulate setting an owner
        revert("Not implemented yet");
    }

    function setTTL(bytes32 node, uint64 ttl) external override {
        // Simple logic or revert to simulate setting TTL
        revert("Not implemented yet");
    }

    // Helper function to handle the receipt checking
<<<<<<< HEAD
    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory _data)
        private
        returns (bool)
    {
=======
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
>>>>>>> main
        return true;
    }

    /**
     * @dev Mints a new token with a given tokenId and assigns it to an owner.
     * @param tokenId The identifier for the new token (node).
     * @param to The address that will own the minted token.
     */
    function mint(uint256 tokenId, address to) public {
        require(to != address(0), "ERC721: mint to the zero address");
        require(_owners[tokenId] == address(0), "ERC721: token already minted");

        _owners[tokenId] = to;
        _balances[to] += 1;

        emit Transfer(address(0), to, tokenId);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        require(_owners[tokenId] != address(0), "ERC721: operator query for nonexistent token");
        address owner = ownerOf(tokenId);
<<<<<<< HEAD
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
=======
        return (spender == owner ||
            getApproved(tokenId) == spender ||
            isApprovedForAll(owner, spender));
>>>>>>> main
    }
}

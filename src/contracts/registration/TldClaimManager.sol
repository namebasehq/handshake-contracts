import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "interfaces/registration/ITldClaimManager.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";


// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

contract TldClaimManager is Ownable, ITldClaimManager {

    mapping(bytes32 => bool) public IsNodeRegistered;
    IERC721 public TldNftContract;
    bytes32 public MerkleRoot;

    

    constructor() {
        
    }


    function canClaim(address _addr, bytes32 _namehash, bytes32[] memory _proofs) public view returns (bool) {

    }

    function setMerkleRoot(bytes32 _root) external onlyOwner {
        MerkleRoot = _root;
    }

    function _claimTld(address _addr, bytes32 _namehash, bytes32[] memory _proofs) private {
        require(canClaim(_addr, _namehash, _proofs), "not eligible to claim");
        require(MerkleProof.verify(_proofs, MerkleRoot, keccak256(abi.encodePacked(_addr))), "not authorised");
    }





}
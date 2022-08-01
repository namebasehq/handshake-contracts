import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "interfaces/ITldClaimManager.sol";
import "src/contracts/HandshakeTld.sol";

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

contract TldClaimManager is Ownable, ITldClaimManager {
    mapping(bytes32 => bool) public IsNodeRegistered;

    HandshakeTld public HandshakeTldContract;

    bytes32 public MerkleRoot;

    constructor() {}

    function canClaim(
        address _addr,
        bytes32 _namehash,
        bytes32[] memory _proofs
    ) public view returns (bool) {
        return
            MerkleProof.verify(
                _proofs,
                MerkleRoot,
                keccak256(abi.encodePacked(_addr, _namehash))
            ) && !IsNodeRegistered[_namehash];
    }

    function setMerkleRoot(bytes32 _root) external onlyOwner {
        MerkleRoot = _root;
    }

    function setHandshakeTldContract(HandshakeTld _tld) external onlyOwner {
        HandshakeTldContract = _tld;
    }

    function claimTld(
        address _addr,
        string calldata _domain,
        bytes32[] memory _proofs
    ) external {
        bytes32 namehash = keccak256(abi.encodePacked(_domain));
        require(canClaim(_addr, namehash, _proofs), "not eligible to claim");
        IsNodeRegistered[namehash] = true;
        HandshakeTldContract.mint(_addr, _domain);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "interfaces/IHandshakeTld.sol";
import "interfaces/ITldClaimManager.sol";

contract TldClaimManager is Ownable, ITldClaimManager {
    mapping(bytes32 => bool) public isNodeRegistered;
    mapping(address => bool) public allowedTldManager;
    mapping(bytes32 => address) public tldClaimantMap;
    mapping(bytes32 => address) public tldProviderMap;

    IHandshakeTld public handshakeTldContract;

    event UpdateAllowedTldManager(address indexed _addr, bool _allowed);

    constructor() {}

    //provide this as a public function in case we want to query it from the UI
    function canClaim(address _addr, bytes32 _namehash) public view returns (bool) {
        return tldClaimantMap[_namehash] == _addr && !isNodeRegistered[_namehash];
    }

    function setHandshakeTldContract(IHandshakeTld _tld) external onlyOwner {
        handshakeTldContract = _tld;
    }

    function claimTld(string calldata _domain) external {
        bytes32 namehash = keccak256(abi.encodePacked(_domain));
        require(canClaim(msg.sender, namehash), "not eligible to claim");
        isNodeRegistered[namehash] = true;
        handshakeTldContract.register(msg.sender, _domain);
    }

    //can also be removed by setting address to 0x0
    function addTldAndClaimant(address[] calldata _addr, string[] calldata _domain)
        external
        onlyAuthorisedTldManager
    {
        require(
            _addr.length == _domain.length,
            "address and domain list should be the same length"
        );
        for (uint256 i; i < _addr.length; ) {
            tldClaimantMap[keccak256(abi.encodePacked(_domain[i]))] = _addr[i];
            tldProviderMap[keccak256(abi.encodePacked(_domain[i]))] = msg.sender;
            unchecked {
                ++i;
            }
        }
    }

    function updateAllowedTldManager(address _addr, bool _allowed) external onlyOwner {
        allowedTldManager[_addr] = _allowed;
        emit UpdateAllowedTldManager(_addr, _allowed);
    }

    modifier onlyAuthorisedTldManager() {
        require(allowedTldManager[msg.sender], "not authorised to add TLD");
        _;
    }
}

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "interfaces/ITldClaimManager.sol";
import "src/contracts/HandshakeTld.sol";

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

contract TldClaimManager is Ownable, ITldClaimManager {

    mapping(bytes32 => bool) public IsNodeRegistered;
    mapping(address => bool) public AllowedTldManager;
    mapping(bytes32 => address) public TldClaimantMap;
    mapping(bytes32 => address) public TldProviderMap;

    HandshakeTld public HandshakeTldContract;

    event UpdateAllowedTldManager(address indexed _addr, bool _allowed);

    bytes32 public MerkleRoot;

    constructor() {}

    //provide this as a public function in case we want to query it from the UI
    function canClaim(address _addr, bytes32 _namehash) public view returns (bool) {
        return TldClaimantMap[_namehash] == _addr && !IsNodeRegistered[_namehash];
    }

    function setHandshakeTldContract(HandshakeTld _tld) external onlyOwner {
        HandshakeTldContract = _tld;
    }

    function claimTld(string calldata _domain) external {
        bytes32 namehash = keccak256(abi.encodePacked(_domain));
        require(canClaim(msg.sender, namehash), "not eligible to claim");
        IsNodeRegistered[namehash] = true;
        HandshakeTldContract.mint(msg.sender, _domain);
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
            TldClaimantMap[keccak256(abi.encodePacked(_domain[i]))] = _addr[i];
            TldProviderMap[keccak256(abi.encodePacked(_domain[i]))] = msg.sender;
            unchecked {
                ++i;
            }
        }
    }

    function updateAllowedTldManager(address _addr, bool _allowed) external onlyOwner {
        AllowedTldManager[_addr] = _allowed;
        emit UpdateAllowedTldManager(_addr, _allowed);
    }

    modifier onlyAuthorisedTldManager() {
        require(AllowedTldManager[msg.sender], "not authorised to add TLD");
        _;
    }
}

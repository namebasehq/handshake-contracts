// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "interfaces/IHandshakeTld.sol";

interface ITldClaimManager {
    function canClaim(address _addr, bytes32 _namehash) external view returns (bool);

    function claimTld(string calldata _domain, address _addr) external payable;

    function setHandshakeTldContract(IHandshakeTld _tld) external;

    function updateAllowedTldManager(address _addr, bool _allowed) external;

    function allowedTldManager(address _addr) external view returns (bool);

    function addTldAndClaimant(address[] calldata _addr, string[] calldata _domain) external;

    function tldExpiry(bytes32 _node) external view returns (uint256);

    event TldClaimed(address indexed _to, uint256 indexed _id, string _label);

    event UpdateAllowedTldManager(address indexed _addr, bool _allowed);

    event AllowedTldMintUpdate(address indexed _claimant, address indexed _manager, string _label);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "interfaces/ITldClaimManager.sol";

contract MockClaimManager is ITldClaimManager {
    function canClaim(address _addr, bytes32 _namehash) external view returns (bool) {}

    function claimTld(string calldata _domain, address _addr) external payable {}

    function setHandshakeTldContract(IHandshakeTld _tld) external {}

    function updateAllowedTldManager(address _addr, bool _allowed) external {}

    function allowedTldManager(address _addr) external view returns (bool) {}

    function addTldAndClaimant(address[] calldata _addr, string[] calldata _domain) external {}
}

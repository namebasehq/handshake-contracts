// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

interface ISldRegistrationManager {

    function purchaseSingleDomain(
        string calldata _label,
        bytes32 _secret,
        uint256 _registrationLength,
        bytes32 _parentNamehash,
        bytes32[] calldata _proofs,
        address _recipient
    ) external payable;

    function renewSubdomain(bytes32 _subdomainHash, uint256 _registrationLength) external payable;
}

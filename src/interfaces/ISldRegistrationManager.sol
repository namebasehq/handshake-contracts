// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "structs/SubdomainRegistrationDetail.sol";

interface ISldRegistrationManager {
    function registerSld(
        string calldata _label,
        bytes32 _secret,
        uint256 _registrationLength,
        bytes32 _parentNamehash,
        address _recipient
    ) external payable;

    function renewSubdomain(
        string calldata _label,
        bytes32 _parentNamehash,
        uint80 _registrationLength
    ) external payable;

    function getRenewalPricePerDay(
        bytes32 _parentNamehash,
        string calldata _label,
        uint256 _registrationLength
    ) external view returns (uint256);

    function subdomainRegistrationHistory(bytes32 _subdomainNamehash)
        external
        view
        returns (
            uint80,
            uint80,
            uint96
        );
}

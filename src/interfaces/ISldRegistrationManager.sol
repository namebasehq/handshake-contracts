// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "structs/SldRegistrationDetail.sol";

interface ISldRegistrationManager {
    function registerSld(
        string calldata _label,
        bytes32 _secret,
        uint256 _registrationLength,
        bytes32 _parentNamehash,
        address _recipient
    ) external payable;

    function renewSld(string calldata _label, bytes32 _parentNamehash, uint80 _registrationLength)
        external
        payable;

    function getRenewalPricePerDay(
        address _addr,
        bytes32 _parentNamehash,
        string calldata _label,
        uint256 _registrationLength
    ) external view returns (uint256);

    function sldRegistrationHistory(bytes32 _sldNamehash)
        external
        view
        returns (uint80, uint80, uint96);

    event RegisterSld(
        bytes32 indexed _tldNamehash,
        bytes32 _secret,
        string _label,
        uint256 _expiry
    );
    event RenewSld(bytes32 indexed _tldNamehash, string _label, uint256 _expiry);
}

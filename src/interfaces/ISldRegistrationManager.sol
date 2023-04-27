// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "interfaces/IHandshakeTld.sol";
import "interfaces/IGlobalRegistrationRules.sol";

interface ISldRegistrationManager {
    function registerWithCommit(
        string calldata _label,
        bytes32 _secret,
        uint256 _registrationLength,
        bytes32 _parentNamehash,
        address _recipient
    ) external payable;

    function registerWithSignature(
        string calldata _label,
        uint256 _registrationLength,
        bytes32 _parentNamehash,
        address _recipient,
        uint8 v,
        bytes32 r,
        bytes32 s
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

    function tld() external view returns (IHandshakeTld);

    function getRenewalPrice(
        address _addr,
        bytes32 _parentNamehash,
        string calldata _label,
        uint256 _registrationLength
    ) external view returns (uint256 _price);

    function globalStrategy() external view returns (IGlobalRegistrationRules);

    function pricesAtRegistration(bytes32 _sldNamehash, uint256 _index)
        external
        view
        returns (uint80);

    event RegisterSld(
        bytes32 indexed _tldNamehash,
        bytes32 _secret,
        string _label,
        uint256 _expiry
    );

    event RenewSld(bytes32 indexed _tldNamehash, string _label, uint256 _expiry);
}

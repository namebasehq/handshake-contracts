// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "interfaces/IHandshakeSld.sol";
import "interfaces/IHandshakeTld.sol";
import "interfaces/ILabelValidator.sol";
import "interfaces/ISldRegistrationManager.sol";
import "structs/SubdomainRegistrationDetail.sol";

contract MockSldRegistrationManager is ISldRegistrationManager {
    mapping(bytes32 => SubdomainRegistrationDetail) public subdomainRegistrationHistory;

    function addSubdomainDetail(
        bytes32 _subdomainNamehash,
        SubdomainRegistrationDetail memory _detail
    ) private {
        subdomainRegistrationHistory[_subdomainNamehash] = _detail;
    }

    function addSubdomainDetail(
        bytes32 _subdomainNamehash,
        uint80 _registrationTime,
        uint80 _registrationLength,
        uint96 _registrationPrice,
        uint128[10] calldata _registrationPriceSnapshot
    ) public {
        SubdomainRegistrationDetail memory detail = SubdomainRegistrationDetail(
            _registrationTime,
            _registrationLength,
            _registrationPrice,
            _registrationPriceSnapshot
        );
        addSubdomainDetail(_subdomainNamehash, detail);
    }

    function registerSld(
        string calldata _label,
        bytes32 _secret,
        uint256 _registrationLength,
        bytes32 _parentNamehash,
        address _recipient
    ) external payable {}

    function renewSubdomain(
        string calldata _label,
        bytes32 _parentNamehash,
        uint80 _registrationLength
    ) external payable {}

    function getRenewalPricePerDay(
        bytes32, //_parentNamehash
        string calldata, //_label
        uint256 //_registrationLength
    ) public pure returns (uint256) {
        require(false, "not implemented");
        return 0;
    }
}

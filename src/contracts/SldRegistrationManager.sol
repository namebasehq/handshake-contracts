// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "interfaces/IHandshakeSld.sol";
import "interfaces/IHandshakeTld.sol";
import "interfaces/ILabelValidator.sol";
import "structs/SubdomainRegistrationDetail.sol";

contract SldRegistrationManager is Ownable {
    mapping(bytes32 => SubdomainRegistrationDetail) public subdomainRegistrationHistory;
    ILabelValidator public validator;
    IHandshakeSld sld;
    IHandshakeTld tld;

    constructor(IHandshakeTld _tld, IHandshakeSld _sld) {
        sld = _sld;
        tld = _tld;
    }

    function purchaseMultipleSld(
        string[] calldata _label,
        bytes32[] calldata _secret,
        uint256[] calldata _registrationLength,
        bytes32[] calldata _parentNamehash,
        address[] calldata _recipient
    ) public payable {}

    function purchaseSingleDomain(
        string calldata _label,
        bytes32 _secret,
        uint256 _registrationLength,
        bytes32 _parentNamehash,
        bytes32[] calldata _proofs,
        address _recipient
    ) external payable {}

    function renewSubdomain(bytes32 _subdomainHash, uint256 _registrationLength) external payable {}

    function updateLabelValidator(ILabelValidator _validator) public onlyOwner {
        validator = _validator;
    }


    function getRenewalPricePerDay(
        SubdomainRegistrationDetail memory _history,
        uint256 _registrationLength
    ) public view returns (uint256) {
        uint256 registrationYears = (_registrationLength / 365); //get the annual rate

        registrationYears = registrationYears > 10 ? 10 : registrationYears;

        uint256 renewalCostPerAnnum = _history.RegistrationPriceSnapshot[registrationYears - 1] /
            registrationYears;
        return renewalCostPerAnnum / 365;
    }


}

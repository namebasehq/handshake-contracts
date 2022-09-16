// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "interfaces/IHandshakeSld.sol";
import "interfaces/IHandshakeTld.sol";
import "interfaces/ILabelValidator.sol";
import "interfaces/IGlobalRegistrationRules.sol";
import "interfaces/ISldRegistrationManager.sol";
import "structs/SubdomainRegistrationDetail.sol";
import "src/utils/Namehash.sol";

contract SldRegistrationManager is Ownable, ISldRegistrationManager {
    mapping(bytes32 => SubdomainRegistrationDetail) public subdomainRegistrationHistory;
    ILabelValidator public labelValidator;
    IGlobalRegistrationRules public globalStrategy;
    IHandshakeSld public sld;
    IHandshakeTld public tld;

    constructor(IHandshakeTld _tld, IHandshakeSld _sld) {
        sld = _sld;
        tld = _tld;
    }

    function registerMultipleSld(
        string[] calldata _label,
        bytes32[] calldata _secret,
        uint256[] calldata _registrationLength,
        bytes32[] calldata _parentNamehash,
        address[] calldata _recipient
    ) public payable {

    }

    function registerSld(
        string calldata _label,
        bytes32 _secret,
        uint256 _registrationLength,
        bytes32 _parentNamehash,
        bytes32[] calldata _proofs,
        address _recipient
    ) external payable {
        require(labelValidator.isValidLabel(_label), "invalid label");

        bytes32 sldNamehash = Namehash.getNamehash(_parentNamehash, _label);

        sld.registerSld(_recipient, _parentNamehash, sldNamehash);

    }

    function renewSubdomain(bytes32 _subdomainHash, uint256 _registrationLength) external payable {

    }

    function canRegister(bytes32 _namehash) private view returns (bool) {
        SubdomainRegistrationDetail memory detail = subdomainRegistrationHistory[_namehash];
        return detail.RegistrationTime + (detail.RegistrationLength * 86400) < block.timestamp;
    }

    function updateLabelValidator(ILabelValidator _validator) public onlyOwner {
        labelValidator = _validator;
    }

    function updateGlobalRegistrationStrategy(IGlobalRegistrationRules _strategy) public onlyOwner {
        globalStrategy = _strategy;
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

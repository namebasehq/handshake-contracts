// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {SldRegistrationManager} from "./SldRegistrationManager.sol";
import {Namehash} from "utils/Namehash.sol";
import {DefaultRegistrationStrategy} from "contracts/DefaultRegistrationStrategy.sol";
import {ISldRegistrationStrategy} from "interfaces/ISldRegistrationStrategy.sol";
import {IHandshakeSld} from "interfaces/IHandshakeSld.sol";
import {IHandshakeTld} from "interfaces/IHandshakeTld.sol";
import {ILabelValidator} from "interfaces/ILabelValidator.sol";
import {LabelValidator} from "contracts/LabelValidator.sol";
import {HandshakeSld} from "contracts/HandshakeSld.sol";

struct DomainDetails {
    bool isAvailable;
    bool labelValid;
    bool publicRegistrationOpen;
    address owner;
    uint256 expiry;
    bool isPremium;
    address reservedAddress;
    uint256 priceInDollars;
    uint256 priceInWei;
}

contract SldStatus {
    SldRegistrationManager public immutable manager;
    HandshakeSld public sld;
    IHandshakeTld public tld;

    constructor(SldRegistrationManager _manager, HandshakeSld _sld, IHandshakeTld _tld) {
        manager = _manager;
        sld = _sld;
        tld = _tld;
    }

    function getDomainDetails(address _buyer, uint256 _registrationDays, bytes32 _parentHash, string calldata _label)
        external
        view
        returns (DomainDetails memory)
    {
        bytes32 sldHash = Namehash.getNamehash(_parentHash, _label);

        (bool isAvailable, bool labelValid, bool publicRegistrationOpen, address owner, uint256 expiry) =
            _getBasicDetails(sldHash, _label);

        (bool isPremium, address reservedAddress, uint256 priceInCents, uint256 priceInWei) =
            _getPricingDetails(_buyer, _registrationDays, _parentHash, _label, sldHash);

        return DomainDetails(
            isAvailable,
            labelValid,
            publicRegistrationOpen,
            owner,
            expiry,
            isPremium,
            reservedAddress,
            priceInCents,
            priceInWei
        );
    }

    function _getBasicDetails(bytes32 sldHash, string calldata _label)
        private
        view
        returns (bool isAvailable, bool labelValid, bool publicRegistrationOpen, address owner, uint256 expiry)
    {
        ILabelValidator labelValidator = LabelValidator(address(manager.labelValidator()));

        bool exists = sld.exists(uint256(sldHash));
        owner = exists ? sld.ownerOf(uint256(sldHash)) : address(0);
        expiry = sld.expiry(sldHash);
        isAvailable = expiry + manager.gracePeriod() < block.timestamp;
        labelValid = labelValidator.isValidLabel(_label);

        ISldRegistrationStrategy interfaceStrategy = sld.getRegistrationStrategy(sldHash);
        DefaultRegistrationStrategy strategy = DefaultRegistrationStrategy(address(interfaceStrategy));
        publicRegistrationOpen = strategy.isEnabled(sldHash);
    }

    function _getPricingDetails(
        address _buyer,
        uint256 _registrationDays,
        bytes32 _parentHash,
        string calldata _label,
        bytes32 sldHash
    ) private view returns (bool isPremium, address reservedAddress, uint256 priceInCents, uint256 priceInWei) {
        ISldRegistrationStrategy interfaceStrategy = sld.getRegistrationStrategy(_parentHash);
        DefaultRegistrationStrategy strategy = DefaultRegistrationStrategy(address(interfaceStrategy));

        uint256 registrationPrice;
        try manager.getRegistrationPrice(address(strategy), _buyer, _parentHash, _label, _registrationDays) returns (
            uint256 price
        ) {
            registrationPrice = price;
        } catch {
            registrationPrice = 0;
        }

        uint256 weiValueOfDollar = manager.getWeiValueOfDollar();
        uint256 premiumPrice = strategy.premiumNames(sldHash);
        reservedAddress = strategy.reservedNames(sldHash);
        priceInCents = registrationPrice / 10 ** 16;
        priceInWei = priceInCents * (weiValueOfDollar / 100);
        isPremium = premiumPrice > 0;
    }
}

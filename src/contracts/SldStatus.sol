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

    function getDomainDetails(
        address _buyer,
        uint256 _registrationDays,
        bytes32 _parentHash,
        string calldata _label
    ) external view returns (DomainDetails memory) {
        bytes32 sldHash = Namehash.getNamehash(_parentHash, _label);

        ISldRegistrationStrategy interfaceStrategy = sld.getRegistrationStrategy(_parentHash);
        DefaultRegistrationStrategy strategy = DefaultRegistrationStrategy(
            address(interfaceStrategy)
        );

        ILabelValidator interfaceValidator = manager.labelValidator();
        LabelValidator labelValidator = LabelValidator(address(interfaceValidator));

        bool exists = sld.exists(uint256(sldHash));

        address owner = exists ? sld.ownerOf(uint256(sldHash)) : address(0);
        uint256 expiry = sld.expiry(sldHash);
        bool isAvailable = expiry + manager.gracePeriod() < block.timestamp;
        bool labelValid = labelValidator.isValidLabel(_label);

        uint256 registrationPrice;
        try
            manager.getRegistrationPrice(
                address(strategy),
                _buyer,
                _parentHash,
                _label,
                _registrationDays
            )
        {
            registrationPrice = manager.getRegistrationPrice(
                address(strategy),
                _buyer,
                _parentHash,
                _label,
                _registrationDays
            );
        } catch {
            registrationPrice = 0;
        }

        uint256 weiValueOfDollar = manager.getWeiValueOfDollar();

        bool publicRegistrationOpen = strategy.isEnabled(_parentHash);

        uint256 premiumPrice = strategy.premiumNames(sldHash);
        address reservedAddress = strategy.reservedNames(sldHash);
        uint256 priceInCents = registrationPrice / 10 ** 16;
        uint256 priceInWei = priceInCents * (weiValueOfDollar / 100);
        bool isPremium = premiumPrice > 0;
        DomainDetails memory details = DomainDetails(
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

        return details;
    }
}

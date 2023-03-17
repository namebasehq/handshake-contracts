// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * Registration manager errors can be used by TLD and SLD manager
 * @title Handshake Sld Registration Manager
 * @author hodl.esf.eth
 */
abstract contract RegistrationManagerErrors {
    error InvalidArrayLength();
    error DomainNotExists();
    error DomainExists();
    error InvalidLabel();
    error InvalidStrategy();
    error StrategyDisabled();
    error GlobalValidationFailed();
    error InvalidCommitment();
    error NotEligible();
    error InvalidManager();
    error InvalidRegistrationLength();
    error InvalidAddress();
}

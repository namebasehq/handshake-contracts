// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.15;

struct SubdomainRegistrationDetail {
    uint72 RegistrationTime;
    uint72 RegistrationLength;
    uint24 RegistrationPrice;
    uint24[10] RegistrationPriceSnapshot;
}

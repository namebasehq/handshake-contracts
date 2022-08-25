// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

struct SubdomainRegistrationDetail {
    uint80 RegistrationTime;
    uint80 RegistrationLength;
    uint96 RegistrationPrice;
    uint48[10] RegistrationPriceSnapshot;
}

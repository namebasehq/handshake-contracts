// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

struct SldDiscountSettings {

    uint80 startTimestamp;
    uint80 endTimestamp;
    uint8 discountPercentage;
    bool isRegistration;
    bool isRenewal;

}
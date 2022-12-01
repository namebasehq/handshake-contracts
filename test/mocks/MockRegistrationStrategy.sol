// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "interfaces/ISldRegistrationStrategy.sol";
import {console} from "forge-std/console.sol";

contract MockRegistrationStrategy is ISldRegistrationStrategy {
    uint256 public price;
    uint128[10] public multiYearPricing;
    bool public isDisabledBool;

    constructor(uint256 _price) {
        price = _price;
    }

    function getPriceInDollars(
        address, // _buyingAddress,
        bytes32, // _parentNamehash,
        string memory, // _label,
        uint256 _registrationLength
    ) external view returns (uint256) {
        uint256 annualCost;

        if (multiYearPricing[0] > 0) {
            uint256 yearCount = _registrationLength / 365;

            require(yearCount > 0, "invalid mock setUp");
            annualCost = multiYearPricing[yearCount - 1];
        } else {
            annualCost = price;
        }

        return (annualCost * _registrationLength) / 365;
    }

    function setMultiYearPricing(uint128[10] calldata _tenYearPricing) external {
        multiYearPricing = _tenYearPricing;
    }

    function setIsDisabled(bool _bool) external {
        isDisabledBool = _bool;
    }

    function isDisabled(bytes32 _parentNamehash) external view returns (bool) {
        return isDisabledBool;
    }

    function supportsInterface(bytes4 interfaceId) public view override(IERC165) returns (bool) {
        return
            interfaceId == this.supportsInterface.selector ||
            interfaceId == this.isDisabled.selector ||
            interfaceId == this.getPriceInDollars.selector;
    }

    function addressDiscounts(bytes32 _namehash, address _addr) external returns (uint256) {
        return 0;
    }
}

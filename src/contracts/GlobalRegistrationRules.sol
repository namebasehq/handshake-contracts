// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {console} from "forge-std/console.sol";
import "interfaces/IGlobalRegistrationRules.sol";

contract GlobalRegistrationRules is IGlobalRegistrationRules {
    uint256 private constant DAYS_IN_A_YEAR = 365;
    uint256 private constant MIN_DOLLAR_COST = 1;

    function canRegister(
        address, // _buyingAddress,
        bytes32, // _parentNamehash,
        string calldata, // _label,
        uint256 _registrationLength,
        uint256 _dollarCost
    ) external pure returns (bool) {
        return
            (_registrationLength / DAYS_IN_A_YEAR) > 0 &&
            ((_dollarCost * DAYS_IN_A_YEAR) / _registrationLength) >= 1 ether;
    }

    function supportsInterface(bytes4 _interfaceId) external pure returns (bool) {
        return
            _interfaceId == this.canRegister.selector ||
            _interfaceId == this.supportsInterface.selector;
    }
}

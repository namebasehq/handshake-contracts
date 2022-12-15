// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {console} from "forge-std/console.sol";
import "interfaces/IGlobalRegistrationRules.sol";

contract GlobalRegistrationRules is IGlobalRegistrationRules {
    uint256 private constant DAYS_IN_A_YEAR = 365;
    uint256 public constant minimumDollarPrice = 1 ether;

    function canRegister(
        address, // _buyingAddress,
        bytes32, // _parentNamehash,
        string calldata, // _label,
        uint256 _registrationLength,
        uint256 _dollarCost
    ) external pure returns (bool) {
        require((_registrationLength / DAYS_IN_A_YEAR) > 0, "less than 365 days registration");
        require(((_dollarCost * DAYS_IN_A_YEAR) / _registrationLength) >= minimumDollarPrice, "min price $1/year");
        return true;
    }

    function supportsInterface(bytes4 _interfaceId) external pure returns (bool) {
        return
            _interfaceId == this.canRegister.selector ||
            _interfaceId == this.supportsInterface.selector;
    }
}

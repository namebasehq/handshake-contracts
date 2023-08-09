// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "interfaces/IGlobalRegistrationRules.sol";

contract GlobalRegistrationRules is IGlobalRegistrationRules {
    uint256 private constant MIN_REGISTRATION_DAYS = 1;
    uint256 private constant MIN_RENEWAL_DAYS = 1;
    uint256 private constant DAYS_IN_A_YEAR = 365;
    uint256 public constant minimumDollarPrice = 1 ether;

    function canRegister(
        address, // _buyingAddress,
        bytes32, // _parentNamehash,
        string calldata, // _label,
        uint256 _registrationLength,
        uint256 _dollarCost
    ) external pure returns (bool) {
        require(_registrationLength >= MIN_REGISTRATION_DAYS, "less than min days registration");
        require(
            ((_dollarCost * DAYS_IN_A_YEAR) / _registrationLength) >= minimumDollarPrice,
            "min price $1/year"
        );
        return true;
    }

    function canRenew(
        address, // _buyingAddress,
        bytes32, // _parentNamehash,
        string calldata, // _label,
        uint256 _renewalLength,
        uint256 _dollarCost
    ) external pure returns (bool) {
        require(_renewalLength >= MIN_RENEWAL_DAYS, "less than 365 days renewal");
        require(
            ((_dollarCost * DAYS_IN_A_YEAR) / _renewalLength) >= minimumDollarPrice,
            "min price $1/year"
        );
        return true;
    }

    function supportsInterface(bytes4 _interfaceId) external pure returns (bool) {
        return
            _interfaceId == this.canRegister.selector ||
            _interfaceId == this.supportsInterface.selector;
    }
}

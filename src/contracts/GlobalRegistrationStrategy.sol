// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "interfaces/IGlobalRegistrationStrategy.sol";

contract GlobalRegistrationStrategy is IGlobalRegistrationStrategy {
    uint256 private constant MIN_REGISTRATION_DAYS = 365;
    uint256 private constant MIN_DOLLAR_COST = 1;

    function canRegister(
        address _buyingAddress,
        bytes32 _parentNamehash,
        string calldata _label,
        uint256 _registrationLength,
        uint256 _dollarCost
    ) external view returns (bool) {
        uint256 numberOfYears = (_registrationLength / MIN_REGISTRATION_DAYS);

        return numberOfYears > 0 && _dollarCost / (numberOfYears) >= 1;
    }

    function supportsInterface(bytes4 _interfaceId) external view returns (bool) {
        return
            _interfaceId == this.canRegister.selector ||
            _interfaceId == this.supportsInterface.selector;
    }
}

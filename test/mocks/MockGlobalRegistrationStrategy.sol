// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "interfaces/IGlobalRegistrationRules.sol";

contract MockGlobalRegistrationStrategy is IGlobalRegistrationRules {
    bool private shouldRegister;
    uint256 private minPrice;

    constructor(bool _canRegister, uint256 _minPrice) {
        shouldRegister = _canRegister;
        minPrice = _minPrice;
    }

    function canRegister(
        address, //_buyingAddress
        bytes32, //_parentNamehash
        string calldata, //_label
        uint256, //_registrationLength
        uint256 // _dollarCost
    ) external view returns (bool) {
        return shouldRegister;
    }

    function minimumDollarPrice() external view returns (uint256) {
        return minPrice;
    }

    function supportsInterface(bytes4 _interfaceId) external pure returns (bool) {
        return
            _interfaceId == this.canRegister.selector ||
            _interfaceId == this.supportsInterface.selector;
    }
}

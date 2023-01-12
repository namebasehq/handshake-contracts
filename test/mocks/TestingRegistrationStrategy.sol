// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "interfaces/ISldRegistrationStrategy.sol";

contract TestingRegistrationStrategy is ISldRegistrationStrategy {
    uint256 public lowestLimit;

    function getPriceInDollars(
        address, // _buyingAddress,
        bytes32, // _parentNamehash,
        string memory, // _label,
        uint256 _registrationLength,
        bool _isRenewal
    ) external view returns (uint256) {
        uint256 counter = 0;
        uint256 startingGas = gasleft();

        while (startingGas - gasleft() < lowestLimit) counter++;

        if (_isRenewal) {
            return (_registrationLength * 2 ether) / 365;
        } else {
            return (_registrationLength * 3 ether) / 365;
        }
    }

    function setLowerLimit(uint256 _limit) external {
        lowestLimit = _limit;
    }

    function isEnabled(bytes32) external pure returns (bool) {
        return true;
    }

    function supportsInterface(bytes4 interfaceId) public pure override(IERC165) returns (bool) {
        return
            interfaceId == this.supportsInterface.selector ||
            interfaceId == this.isEnabled.selector ||
            interfaceId == this.getPriceInDollars.selector ||
            interfaceId == this.addressDiscounts.selector;
    }

    function addressDiscounts(bytes32, address) external pure returns (uint256) {
        return 0;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "interfaces/ISldRegistrationStrategy.sol";

contract MockRegistrationStrategy is ISldRegistrationStrategy {
    uint256 public Price;

    constructor(uint256 _price) {
        Price = _price;
    }

    function getPriceInDollars(
        address _buyingAddress,
        bytes32 _parentNamehash,
        string memory _label,
        uint256 _registrationLength
    ) external view returns (uint256) {
        return (Price * _registrationLength) / 365;
    }

    function supportsInterface(bytes4 interfaceID) public view override returns (bool) {
        return
            interfaceID == this.supportsInterface.selector || // ERC165
            interfaceID == this.getPriceInDollars.selector;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "interfaces/ISldPriceStrategy.sol";

contract MockPriceStrategy is ISldPriceStrategy {
    uint256 public Price;

    constructor(uint256 _price) {
        Price = _price;
    }

    function getPriceInDollars(
        address _buyingAddress,
        bytes32 _parentNamehash,
        string memory _label,
        uint256 _registrationLength,
        bytes32[] calldata _proofs
    ) external view returns (uint256) {
        return Price;
    }

    function supportsInterface(bytes4 interfaceID) public view override returns (bool) {
        return
            interfaceID == this.supportsInterface.selector || // ERC165
            interfaceID == this.getPriceInDollars.selector;
    }
}

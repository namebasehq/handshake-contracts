// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "interfaces/IGlobalRegistrationStrategy.sol";

contract GlobalRegistrationStrategy is IGlobalRegistrationStrategy {

    uint256 private constant MIN_REGISTRATION_DAYS = 364;
    uint256 private constant MIN_DOLLAR_COST = 1;

    function canRegister(
        address _buyingAddress,
        bytes32 _parentNamehash,
        string calldata _label,
        uint256 _registrationLength,
        uint256 _dollarCost
    ) external view returns (bool){


            return _dollarCost / ((_registrationLength / 365) + 1) >= 1 && _registrationLength > MIN_REGISTRATION_DAYS;
    }

    function supportsInterface(bytes4 _interfaceId) external view returns (bool){

        return _interfaceId == this.canRegister.selector || _interfaceId == this.supportsInterface.selector;
    }









}
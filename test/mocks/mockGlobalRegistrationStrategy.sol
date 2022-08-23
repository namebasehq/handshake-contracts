// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "interfaces/IGlobalRegistrationStrategy.sol";

contract MockGlobalRegistrationStrategy is IGlobalRegistrationStrategy {

    bool private shouldRegister;

    constructor(bool _canRegister) {
        shouldRegister = _canRegister;
    }


    function canRegister(
        address _buyingAddress,
        bytes32 _parentNamehash,
        string calldata _label,
        uint256 _registrationLength,
        uint256 _dollarCost
    ) external view returns (bool){

        return shouldRegister;

    }

    function supportsInterface(bytes4 _interfaceId) external view returns (bool){

        return _interfaceId == this.canRegister.selector || _interfaceId == this.supportsInterface.selector;
    }









}
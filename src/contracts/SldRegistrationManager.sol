// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";

contract SldRegistrationManager is Ownable {
    constructor() {



    }

        function purchaseMultipleSld(
        string[] calldata _label,
        bytes32[] calldata _secret,
        uint256[] calldata _registrationLength,
        bytes32[] calldata _parentNamehash,
        address[] calldata _recipient
    ) public payable { }
}

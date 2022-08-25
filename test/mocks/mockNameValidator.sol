// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "interfaces/INameValidator.sol";

contract MockNameValidator is INameValidator {
    bool private IsValid;

    constructor(bool _isValid) {
        IsValid = _isValid;
    }

    function isValidName(string memory _name) external returns (bool) {
        return IsValid;
    }
}

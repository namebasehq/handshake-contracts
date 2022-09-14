// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "interfaces/ILabelValidator.sol";

contract MockLabelValidator is ILabelValidator {
    bool private IsValid;

    constructor(bool _isValid) {
        IsValid = _isValid;
    }

    function isValidLabel(string calldata _label) external view returns (bool) {
        return IsValid;
    }
}

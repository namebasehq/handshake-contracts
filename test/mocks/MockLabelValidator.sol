// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "interfaces/ILabelValidator.sol";

contract MockLabelValidator is ILabelValidator {
    bool private IsValid;

    constructor(bool _isValid) {
        IsValid = _isValid;
    }

    function isValidLabel(string calldata) external view returns (bool) {
        return IsValid;
    }
}

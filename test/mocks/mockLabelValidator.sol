// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "interfaces/IDomainValidator.sol";

contract MockLabelValidator is IDomainValidator {
    bool private IsValid;

    constructor(bool _isValid) {
        IsValid = _isValid;
    }

    function isValidLabel(string memory _label) external returns (bool) {
        return IsValid;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "interfaces/INameValidator.sol";

contract NameValidator is INameValidator {
    function isValidName(string memory _name) external pure returns (bool) {
        bytes memory b = bytes(_name);
        uint256 _length = b.length;
        if (_length == 0) return false;
        if (_length > 255) return false;
        for(uint i = 0; i < _length; i++){
            bytes1 char = b[i];
            if (
                !(char >= 0x30 && char <= 0x39) && // 0-9 numeric
                !(char >= 0x61 && char <= 0x7A) && // a-z lowercase letters
                !(char == 0x2E) && // . period
                !(char == 0x2D) // - hyphen
                // !(char == 0x5F) // _ underscore
            )
                return false;
        }
        return true;
    }
}

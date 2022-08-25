// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "strings/strings.sol";
import "interfaces/INameValidator.sol";

contract NameValidator is INameValidator {
    using strings for *;

    // currently using Handshake validation rules, except not allowing underscores
    // https://github.com/handshake-org/hsd/blob/master/lib/covenants/rules.js#L183
    // https://en.wikipedia.org/wiki/Domain_Name_System#Domain_name_syntax,_internationalization
    uint256 public maxLabelLength = 63; // max individual length of SLDs and TLDs

    function isValidName(string memory _label) external view returns (bool) {

        // convert label to lowercase
        // string memory _str = lower(_label);

        if (strings.len(strings.toSlice(_label)) == 0) return false;
        if (bytes(_label).length > maxLabelLength) return false;
        if (strings.count(strings.toSlice(_label), strings.toSlice(".")) > 0) return false;
        if (strings.count(strings.toSlice(_label), strings.toSlice(" ")) > 0) return false;

        bytes memory _bytes = bytes(_label);
        uint256 _length = _bytes.length;
        // if (_length == 0) return false;
        // if (_length > maxLabelLength) return false;
        for (uint i = 0; i < _length; i++) {
            bytes1 char = _bytes[i];
            if (
                !(char >= 0x30 && char <= 0x39) && // 0-9 numeric
                !(char >= 0x61 && char <= 0x7A) && // a-z lowercase letters
                !(char == 0x2D) // - hyphen
                // !(char == 0x2E) && // . period
                // !(char == 0x5F) // _ underscore
            )
            return false;
        }
        return true;
    }


    /**
     * Converts all the values of a string to their corresponding lower case
     * value.
     * 
     * @param _base When being used for a data type this is the extended object
     *              otherwise this is the string base to convert to lower case
     * @return string 
     */
    function lower(string memory _base)
        internal
        pure
        returns (string memory) {
        bytes memory _baseBytes = bytes(_base);
        for (uint i = 0; i < _baseBytes.length; i++) {
            _baseBytes[i] = _lower(_baseBytes[i]);
        }
        return string(_baseBytes);
    }

    /**
     * Convert an alphabetic character to lower case and return the original
     * value when not alphabetic
     * 
     * @param _b1 The byte to be converted to lower case
     * @return bytes1 The converted value if the passed value was alphabetic
     *                and in a upper case otherwise returns the original value
     */
    function _lower(bytes1 _b1)
        private
        pure
        returns (bytes1) {

        if (_b1 >= 0x41 && _b1 <= 0x5A) {
            return bytes1(uint8(_b1) + 32);
        }

        return _b1;
    }
}

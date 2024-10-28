// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "interfaces/ILabelValidator.sol";

contract LabelValidator is ILabelValidator {
    // max individual length of SLDs and TLDs
    uint256 public constant MAX_LABEL_LENGTH = 63;

    /**
     * Currently using Handshake/DNS validation rules -- except that we're not allowing underscores which are not commonly supported in domains.
     * We have chosen to limit all names to alphanumeric ASCII, hyphens, and punycode in order to avoid compatibility issues with EPP and existing registrars.
     * https://github.com/handshake-org/hsd/blob/master/lib/covenants/rules.js#L183
     * https://en.wikipedia.org/wiki/Domain_Name_System#Domain_name_syntax,_internationalization
     * @param _label The label to validate. Should be normalized to lowercase without spaces, periods, or non-alphanumeric characters.
     * @return bool Label is valid
     */
    function isValidLabel(string calldata _label) external pure returns (bool) {
        bytes memory labelBytes = bytes(_label);
        uint256 bytesLength = labelBytes.length;
        if (bytesLength == 0) return false;
        if (bytesLength > MAX_LABEL_LENGTH) return false;
        // hyphen not allowed at end or beginning
        if (labelBytes[0] == 0x2D || labelBytes[bytesLength - 1] == 0x2D) return false;
        // double hyphen not allowed at positions 3 & 4, this prevents punycode
        // if (bytesLength > 3 && labelBytes[2] == 0x2D && labelBytes[3] == 0x2D) return false;
        for (uint256 i; i < bytesLength;) {
            bytes1 char = labelBytes[i];
            if (
                // only allow a-z,0-9,-
                !(char >= 0x30 && char <= 0x39) // 0-9 numeric
                    && !(char >= 0x61 && char <= 0x7A) // a-z lowercase letters
                    && !(char == 0x2D) // - hyphen
                    // !(char == 0x5F) // _ underscore
            ) return false;
            unchecked {
                ++i;
            }
        }
        return true;
    }
}

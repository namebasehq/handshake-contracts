// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "interfaces/ILabelValidator.sol";

contract HasLabelValidator {
    ILabelValidator public labelValidator;

    event NewLabelValidator(address indexed _labelValidator);
}

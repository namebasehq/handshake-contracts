// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "interfaces/ILabelValidator.sol";
import "contracts/UsdPriceOracle.sol";

contract HasLabelValidator {
    ILabelValidator public labelValidator;

    constructor(ILabelValidator _validator) {
        labelValidator = _validator;
    }

    event NewLabelValidator(address indexed _labelValidator);
}

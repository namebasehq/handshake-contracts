// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

interface ILabelValidator {
    function isValidLabel(string calldata _label) external returns (bool);
}

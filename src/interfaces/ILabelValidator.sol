// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ILabelValidator {
    function isValidLabel(string calldata _label) external view returns (bool);
}

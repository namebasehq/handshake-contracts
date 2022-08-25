// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

interface IDomainValidator {
    function isValidLabel(string memory _label) external returns (bool);
}

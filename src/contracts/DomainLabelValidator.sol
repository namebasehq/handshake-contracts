// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;


import "interfaces/IDomainValidator.sol";


contract DomainLabelValidator is IDomainValidator {

    function isValidLabel(string memory _label) external returns (bool){
        require(false, "not implemented");
        return false;
    }

}
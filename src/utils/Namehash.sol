// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "utils/BytesUtils.sol";

library Namehash {
    using BytesUtils for bytes;

    // TODO: use BytesUtils version?
    function getLabelhash(string memory _label) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_label));
    }


    function getNamehash(bytes32 _parentHash, string memory _label) public pure returns (bytes32) {
        bytes32 labelhash = keccak256(abi.encodePacked(_label));
        return keccak256(abi.encodePacked(_parentHash, labelhash));
    }

    function getTldNamehash(string memory _label) public pure returns (bytes32) {
        return getNamehash(bytes32(0), _label);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "utils/BytesUtils.sol";

library Namehash {
    using BytesUtils for bytes;

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

    function getDomainNamehash(string calldata _domain) public pure returns (bytes32) {
        bytes memory bytesDomain = bytes(_domain);
        uint256 length = bytesDomain.length;
        bytes32 node = 0;
        uint8 labelLength = 0;

        // use unchecked to save gas since we check for an underflow
        // and we check for the length before the loop
        unchecked {
            for (uint256 i = length - 1; i >= 0; i--) {
                if (bytesDomain[i] == ".") {
                    node = keccak256(
                        abi.encodePacked(node, bytesDomain.keccak(i + 1, labelLength))
                    );
                    labelLength = 0;
                } else {
                    labelLength += 1;
                }
                if (i == 0) {
                    break;
                }
            }
        }

        node = keccak256(abi.encodePacked(node, bytesDomain.keccak(0, labelLength)));

        return node;
    }
}

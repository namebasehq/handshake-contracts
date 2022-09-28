// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "interfaces/IMetadataService.sol";

contract MockMetadataService is IMetadataService {
    string public ReturnValue;

    constructor(string memory _returnValue) {
        ReturnValue = _returnValue;
    }

    function tokenURI(bytes32) external view returns (string memory) {
        return ReturnValue;
    }

    function supportsInterface(bytes4 interfaceID) public pure override returns (bool) {
        return
            interfaceID == this.supportsInterface.selector || // ERC165
            interfaceID == this.tokenURI.selector;
    }
}

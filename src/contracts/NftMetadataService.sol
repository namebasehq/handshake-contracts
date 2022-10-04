// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "interfaces/IMetadataService.sol";

contract NftMetadataService is IMetadataService {
    string private baseUri;

    constructor(string memory _baseUri) {
        baseUri = _baseUri;
    }

    function tokenURI(bytes32 _namehash) external view returns (string memory) {
        return string(abi.encodePacked(baseUri, uint256(_namehash)));
    }

    function supportsInterface(bytes4 interfaceID) public view override returns (bool) {
        return
            interfaceID == this.supportsInterface.selector || // ERC165
            interfaceID == this.tokenURI.selector;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "interfaces/IMetadataService.sol";
import "contracts/HandshakeNft.sol";

contract NftMetadataService is IMetadataService {
    HandshakeNft nft;

    constructor(HandshakeNft _nft) {
        nft = _nft;
    }

    function tokenURI(bytes32 _namehash) external view returns (string memory) {
        return "";
    }

    function supportsInterface(bytes4 interfaceID) public view override returns (bool) {
        return
            interfaceID == this.supportsInterface.selector || // ERC165
            interfaceID == this.tokenURI.selector;
    }
}

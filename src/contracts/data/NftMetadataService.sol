// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "interfaces/data/IMetadataService.sol";

contract NftMetadataService is IMetadataService {

    string private baseUri = "";

function tokenURI(bytes32) external view returns (string memory){
    return baseUri;
}

}
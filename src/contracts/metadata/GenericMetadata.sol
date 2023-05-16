// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "interfaces/IMetadataService.sol";
import "contracts/HandshakeSld.sol";
import "contracts/HandshakeTld.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract GenericMetadataService is IMetadataService {
    using Strings for uint256;
    HandshakeSld public immutable sld;
    HandshakeTld public immutable tld;

    string public BASE_URI;

    constructor(HandshakeSld _sld, HandshakeTld _tld, string memory _baseUri) {
        sld = _sld;
        tld = _tld;
        BASE_URI = _baseUri;
    }

    function tokenURI(bytes32 _namehash) external view returns (string memory) {
        uint256 id = uint256(_namehash);

        if (sld.exists(id) || tld.exists(id)) {
            return string(abi.encodePacked(BASE_URI, id.toString()));
        } else {
            return "";
        }
    }

    function supportsInterface(bytes4 interfaceID) public pure override returns (bool) {
        return
            interfaceID == this.supportsInterface.selector || // ERC165
            interfaceID == this.tokenURI.selector;
    }
}

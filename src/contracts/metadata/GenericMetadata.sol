// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Import necessary interface and contracts
import "interfaces/IMetadataService.sol";
import "contracts/HandshakeSld.sol";
import "contracts/HandshakeTld.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title GenericMetadataService
 * @dev This contract is used to manage and provide metadata for Handshake domains.
 */
contract GenericMetadataService is IMetadataService {
    using Strings for uint256;

    // The Handshake Second-Level Domain (SLD) and Top-Level Domain (TLD) contracts
    HandshakeSld public immutable sld;
    HandshakeTld public immutable tld;

    // The base URI for token metadata
    string public BASE_URI;

    /**
     * @dev Constructs a new instance of the contract.
     * @param _sld The address of the Handshake Second-Level Domain (SLD) contract.
     * @param _tld The address of the Handshake Top-Level Domain (TLD) contract.
     * @param _baseUri The base URI for token metadata.
     */
    constructor(HandshakeSld _sld, HandshakeTld _tld, string memory _baseUri) {
        sld = _sld;
        tld = _tld;
        BASE_URI = _baseUri;
    }

    /**
     * @notice Returns the token URI for a given namehash.
     * @dev If the namehash exists in the SLD or TLD contracts, it returns the concatenation
     *      of the base URI and the string representation of the namehash.
     *      Otherwise, it returns an empty string.
     * @param _namehash The namehash of the domain.
     * @return The URI of the token.
     */
    function tokenURI(bytes32 _namehash) external view returns (string memory) {
        uint256 id = uint256(_namehash);

        if (sld.exists(id) || tld.exists(id)) {
            return string(abi.encodePacked(BASE_URI, id.toString()));
        } else {
            return "";
        }
    }

    /**
     * @notice Checks whether the contract supports a given interface, based on the interface ID.
     * @dev It supports the ERC165 interface (for checking interface support) and the tokenURI function of this contract.
     * @param interfaceID The ID of the interface to check for support.
     * @return True if the interface is supported, False otherwise.
     */
    function supportsInterface(bytes4 interfaceID) public pure override returns (bool) {
        return interfaceID == this.supportsInterface.selector // ERC165
            || interfaceID == this.tokenURI.selector;
    }
}

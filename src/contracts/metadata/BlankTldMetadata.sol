// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "interfaces/IMetadataService.sol";
import "interfaces/IHandshakeSld.sol";
import "contracts/HandshakeNft.sol";
import "src/interfaces/ISldRegistrationManager.sol";
import "interfaces/IResolver.sol";
import "interfaces/IHandshakeSld.sol";

contract BlankTldMetadataService is IMetadataService {
    HandshakeNft public immutable nft;

    //slither-disable-next-line immutable-states
    string internal backgroundColour = "#ffffff";

    constructor(HandshakeNft _nft) {
        nft = _nft;
    }

    function tokenURI(bytes32 _namehash) external view returns (string memory) {
        //can use nft.name(_namehash) to get domain name for embedded SVG.
        return json(_namehash, nft.name(_namehash));
    }

    function supportsInterface(bytes4 interfaceID) public pure override returns (bool) {
        return
            interfaceID == this.supportsInterface.selector || // ERC165
            interfaceID == this.tokenURI.selector;
    }

    function json(bytes32 _namehash, string memory _name) private view returns (string memory) {
        bytes memory data;

        string memory start = "data:application/json;utf8,{";
        bytes memory nftName = abi.encodePacked('"name": "', _name, '",');
        string memory description = '"description": "Transferable Handshake Domain",';
        bytes memory image = abi.encodePacked('"image":"', getImage(_namehash, _name), '",');
        string memory attributeStart = '"attributes":[]}';

        data = abi.encodePacked(start, nftName, description, image, attributeStart);

        return string(data);
    }

    function svg(string memory _name) private view returns (string memory _svg) {
        string memory start = "data:image/svg+xml;utf8,";
        _svg = string(
            abi.encodePacked(
                start,
                "<svg width='600pt' height='600pt' version='1.0' viewBox='0 0 600 600' xmlns='http://www.w3.org/2000/svg'><metadata>Namebase - Sam Ward</metadata><g transform='translate(0 725) scale(.1 -.1)' fill='",
                backgroundColour,
                "'></g><text x='60' y='500' fill='blue' font-size='50' font='sans-serif'>",
                _name,
                "</text></svg>"
            )
        );
    }

    function getImage(bytes32 _namehash, string memory _name)
        private
        view
        returns (string memory _image)
    {
        IResolver resolver = IResolver(nft.tokenResolverMap(_namehash));

        bytes memory data = abi.encodeWithSelector(resolver.text.selector, _namehash, "avatar");

        _image = canGetImageFromResolver(address(resolver), data)
            ? resolver.text(_namehash, "avatar")
            : "";

        if (bytes(_image).length == 0) {
            resolver = IResolver(nft.tokenResolverMap(_namehash));

            data = abi.encodeWithSelector(resolver.text.selector, _namehash, "avatar");

            _image = canGetImageFromResolver(address(resolver), data)
                ? resolver.text(_namehash, "avatar")
                : "";

            if (bytes(_image).length == 0) {
                _image = svg(_name);
            }
        }
    }

    function canGetImageFromResolver(address _address, bytes memory _data)
        public
        view
        returns (bool)
    {
        string memory image;
        bool success;

        assembly {
            let ptr := mload(0x40)
            success := staticcall(
                gas(), // gas remaining
                _address, // destination address
                add(_data, 32), // input buffer (starts after the first 32 bytes in the `data` array)
                mload(_data), // input length (loaded from the first 32 bytes in the `data` array)
                0, // output buffer
                32 // output length
            )
            image := mload(ptr)
        }

        // we would just get image string from this ideally... but it becomes
        // awkward when the string is longer than 32 bytes
        // so.. yeah..
        return success && bytes(image).length > 0;
    }
}

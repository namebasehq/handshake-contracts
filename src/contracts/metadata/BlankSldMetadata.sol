// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "interfaces/IMetadataService.sol";
import "interfaces/IHandshakeSld.sol";
import "interfaces/IHandshakeNft.sol";
import "interfaces/IResolver.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "src/interfaces/ISldRegistrationManager.sol";

contract BlankSldMetadataService is IMetadataService {
    using Strings for uint256;
    IHandshakeSld public immutable sld;
    IHandshakeTld public immutable tld;

    string internal backgroundColour = "#1a2b3c";

    ISldRegistrationManager public immutable registrationManager;

    constructor(
        IHandshakeSld _sld,
        IHandshakeTld _tld,
        ISldRegistrationManager _registrationManager
    ) {
        sld = _sld;
        tld = _tld;
        registrationManager = _registrationManager;
    }

    function tokenURI(bytes32 _namehash) external view returns (string memory) {
        //can use nft.name(_namehash) to get domain name for embedded SVG.

        // need to use the max price and not current price as it can be
        // manipulated using discounts
        uint256 cost = registrationManager.pricesAtRegistration(_namehash, 0);

        return
            json(
                _namehash,
                sld.name(_namehash),
                sld.parent(_namehash),
                sld.expiry(_namehash),
                cost
            );
    }

    function supportsInterface(bytes4 interfaceID) public pure override returns (bool) {
        return
            interfaceID == this.supportsInterface.selector || // ERC165
            interfaceID == this.tokenURI.selector;
    }

    function getImage(bytes32 _namehash, string memory _name)
        private
        view
        returns (string memory _image)
    {
        IHandshakeNft nft = IHandshakeNft(address(sld));

        IResolver resolver = IResolver(nft.tokenResolverMap(_namehash));

        bytes memory data = abi.encodeWithSelector(resolver.text.selector, _namehash, "avatar");

        _image = canGetImageFromResolver(address(resolver), data)
            ? resolver.text(_namehash, "avatar")
            : "";

        if (bytes(_image).length == 0) {
            bytes32 parentHash = sld.namehashToParentMap(_namehash);

            nft = IHandshakeNft(address(tld));
            resolver = IResolver(nft.tokenResolverMap(parentHash));

            data = abi.encodeWithSelector(resolver.text.selector, parentHash, "avatar");

            _image = canGetImageFromResolver(address(resolver), data)
                ? resolver.text(parentHash, "avatar")
                : "";

            if (bytes(_image).length == 0) {
                _image = svg(_name);
            }
        }
    }

    function json(
        bytes32 _namehash,
        string memory _name,
        string memory _parentName,
        uint256 _expiry,
        uint256 _renewalCost
    ) private view returns (string memory) {
        bytes memory data;

        string memory start = "data:application/json;utf8,{";
        bytes memory nftName = abi.encodePacked('"name": "', _name, '",');
        string memory description = '"description": "Transferable Handshake Domain",';
        bytes memory image = abi.encodePacked('"image":"', getImage(_namehash, _name), '",');
        string memory attributeStart = '"attributes":[';

        string memory end = "]}";

        data = abi.encodePacked(start, nftName, description, image, attributeStart);

        bytes memory parentName = abi.encodePacked(
            '{"trait_type" : "TLD", "value" : "',
            _parentName,
            '"},'
        );

        bytes memory expiryText = abi.encodePacked(
            '{"trait_type" : "expiry", "display_type": "date", "value": ',
            _expiry.toString(),
            "},"
        );

        bytes memory renewalCost = abi.encodePacked(
            '{"trait_type" : "Annual Cost", "value": "$',
            (_renewalCost / 1 ether).toString(),
            '"}'
        );

        data = abi.encodePacked(data, parentName, expiryText, renewalCost, end);

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

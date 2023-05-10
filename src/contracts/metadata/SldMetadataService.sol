// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "interfaces/IMetadataService.sol";
import "interfaces/IHandshakeSld.sol";
import "interfaces/IHandshakeNft.sol";
import "interfaces/IResolver.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "src/interfaces/ISldRegistrationManager.sol";

contract SldMetadataService is IMetadataService {
    using Strings for uint256;
    IHandshakeSld public immutable sld;
    IHandshakeTld public immutable tld;
    //slither-disable-next-line immutable-states
    string internal backgroundColour;

    ISldRegistrationManager public immutable registrationManager;

    constructor(
        IHandshakeSld _sld,
        IHandshakeTld _tld,
        ISldRegistrationManager _registrationManager,
        string memory _background
    ) {
        sld = _sld;
        tld = _tld;
        backgroundColour = _background;
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
                _image = svg(_name);
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

        // bytes memory maxRenewalCost = abi.encodePacked(
        //     '{"trait_type" : "max annual cost", "value": "$',
        //     (_maxRenewalCost / 1 ether).toString(),
        //     '"}'
        // );

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
                "'><path d='m0 3605v-3605h3910 3910v3605 3605h-3910-3910v-3605zm1360 3380c0-2-102-186-227-407-291-517-283-502-283-510 0-5 9-17 20-28 19-19 33-20 454-20h434l81-141c45-78 81-143 81-145s-286-5-636-6l-637-3-214-400-166-2c-92-1-168 1-171 5-2 4 178 331 400 727 223 396 432 768 465 828l60 107h169c94 0 170-2 170-5zm170-186c58-93 80-138 76-153-3-11-70-136-149-276l-143-255-167-3c-92-1-167 0-167 4 0 12 455 814 462 814 4 0 43-59 88-131zm981-514c47-77 84-143 82-147-2-5-80-8-172-8h-167l-81 143c-44 78-79 145-76 150 2 4 77 6 166 5l161-3 87-140zm-433-27c108-189 107-152 11-327-72-131-85-150-96-136-27 38-153 263-153 275 0 11 160 310 166 310 1 0 34-55 72-122zm512-223c0-4-107-196-237-428s-328-586-441-787c-112-201-215-382-228-402l-24-38h-166c-145 0-165 2-160 15 3 9 59 111 124 228 66 117 176 314 246 438 69 124 126 232 126 240 0 38-12 39-461 39h-437l-86 148-85 147 637 5c350 3 638 6 639 8 0 1 20 37 43 80 24 42 72 130 107 195l64 117h170c93 0 169-2 169-5zm-1821-593 81-138-79-148c-43-81-83-152-87-156-5-5-45 54-92 135l-82 145 81 150c44 82 85 150 89 150s44-62 89-138zm927-207c-3-9-57-107-119-218-63-111-163-289-222-395-99-176-110-192-122-175-8 10-48 73-89 141l-76 124 143 256c78 141 147 263 152 270 7 9 54 12 174 12 144 0 164-2 159-15zm-1261-7c10-10 155-272 155-279 0-5-74-9-164-9h-164l-80 133c-45 73-84 139-87 147-4 13 19 15 166 13 94-1 173-3 174-5z'/></g><text x='60' y='500' fill='white' font-size='50' font='sans-serif'>",
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

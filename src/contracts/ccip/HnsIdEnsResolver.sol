// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IExtendedResolver.sol";
import "./SignatureVerifier.sol";
import "@ensdomains/ens-contracts/contracts/registry/ENS.sol";
import "@ensdomains/ens-contracts/contracts/wrapper/INameWrapper.sol";

/**
 * Implements an ENS resolver that directs all queries to a CCIP read gateway.
 * Callers must implement EIP 3668 and ENSIP 10.
 */
contract HnsIdEnsResolver is IExtendedResolver, IERC165, Ownable {
    ENS public immutable ens;
    INameWrapper public nameWrapper;

    /**
     * A mapping of authorisations. An address that is authorised for a name
     * may make any changes to the name that the owner could, but may not update
     * the set of authorisations.
     * (node, owner, caller) => isAuthorised
     */
    mapping(bytes32 => mapping(address => mapping(address => bool))) public authorisations;

    mapping(string => string) public tldMappings;

    event AuthorisationChanged(
        bytes32 indexed node,
        address indexed owner,
        address indexed target,
        bool isAuthorised
    );

    /**
     * @dev Sets or clears an authorisation.
     * Authorisations are specific to the caller. Any account can set an authorisation
     * for any name, but the authorisation that is checked will be that of the
     * current owner of a name. Thus, transferring a name effectively clears any
     * existing authorisations, and new authorisations can be set in advance of
     * an ownership transfer if desired.
     *
     * @param node The name to change the authorisation on.
     * @param target The address that is to be authorised or deauthorised.
     * @param _isAuthorised True if the address should be authorised, or false if it should be deauthorised.
     */
    function setAuthorisation(bytes32 node, address target, bool _isAuthorised) external {
        authorisations[node][msg.sender][target] = _isAuthorised;
        emit AuthorisationChanged(node, msg.sender, target, _isAuthorised);
    }

    function isAuthorised(bytes32 node) internal view returns (bool) {
        address owner = ens.owner(node);
        if (owner == address(nameWrapper)) {
            owner = nameWrapper.ownerOf(uint256(node));
        }
        return owner == msg.sender || authorisations[node][owner][msg.sender];
    }

    string public url;
    mapping(address => bool) public signers;

    event NewSigners(address indexed signer, bool isSigner);
    event UpdateUrl(string url);
    event TldChanged(
        bytes32 indexed node, string indexed indexedEns, string indexed indexedTld, string ens, string tld
    );

    error OffchainLookup(address sender, string[] urls, bytes callData, bytes4 callbackFunction, bytes extraData);

    error Unauthorized();
    error InvalidSignature();

    constructor(string memory _url, address[] memory _signers, address _ens, address _wrapper) {
        url = _url;
        emit UpdateUrl(_url);

        ens = ENS(_ens);
        nameWrapper = INameWrapper(_wrapper);

        uint256 arrayLength = _signers.length;
        for (uint256 i; i < arrayLength;) {
            signers[_signers[i]] = true;
            emit NewSigners(_signers[i], true);

            unchecked {
                ++i;
            }
        }
    }

    function makeSignatureHash(address target, uint64 expires, bytes memory request, bytes memory result)
        external
        pure
        returns (bytes32)
    {
        return SignatureVerifier.makeSignatureHash(target, expires, request, result);
    }

    /// @notice Sets text records for the specified TLD node.
    function setText(string calldata _ens, string calldata _tld) external {
        bytes32 node = getDomainNamehash(_ens);

        if (!isAuthorised(node)) {
            revert Unauthorized();
        }

        tldMappings[_ens] = _tld;
        emit TldChanged(node, _ens, _tld, _ens, _tld);
    }

    /**
     * Resolves a name, as specified by ENSIP 10 (wildcard).
     * @param name The DNS-encoded name to resolve.
     * @param data The ABI encoded data for the underlying resolution function (Eg, addr(bytes32), text(bytes32,string), etc).
     * @return The return data, ABI encoded identically to the underlying function.
     */
    function resolve(
        bytes calldata name,
        bytes calldata data
    ) external view override returns (bytes memory) {
        bytes memory callData = abi.encodeWithSelector(
            IExtendedResolver.resolve.selector,
            name,
            data
        );
        string[] memory urls = new string[](1);
        urls[0] = getUrl(name);

        // revert with the OffchainLookup error, which will be caught by the client
        revert OffchainLookup(address(this), urls, callData, HnsIdEnsResolver.resolveWithProof.selector, callData);
    }

    function updateSigners(address[] calldata _signers, bool[] calldata _isSigner) external onlyOwner {
        for (uint256 i; i < _signers.length; i++) {
            signers[_signers[i]] = _isSigner[i];
            emit NewSigners(_signers[i], _isSigner[i]);
        }
    }

    function updateUrl(string calldata _url) external onlyOwner {
        url = _url;
        emit UpdateUrl(_url);
    }

    function getUrl(bytes calldata name) public view returns (string memory) {
        string memory ensName = hexToText(name);
        string memory tld = tldMappings[ensName];

        require(bytes(tld).length > 0, "TLD not found");

        return
            string(abi.encodePacked(url, tld, "/ccip/", ensName, "?sender={sender}&data={data}"));
    }

    /**
     * Callback used by CCIP read compatible clients to verify and parse the response.
     */
    function resolveWithProof(bytes calldata response, bytes calldata extraData) external view returns (bytes memory) {
        (address signer, bytes memory result) = SignatureVerifier.verify(extraData, response);

        if (!signers[signer]) {
            revert InvalidSignature();
        }

        return result;
    }

    function hexToText(bytes memory hexBytes) private pure returns (string memory) {
        uint256 start = 0;
        // Find the first line break (0x0a)
        for (uint256 i = 0; i < hexBytes.length; i++) {
            if (hexBytes[i] == 0x0a) {
                start = i + 1;
                break;
            }
        }

        // Initialize the final bytes array
        bytes memory tempBytes = new bytes(hexBytes.length - start - 1);
        uint256 tempIndex = 0;

        for (uint256 i = start; i < hexBytes.length; i++) {
            if (hexBytes[i] == 0x00) {
                break; // Ignore termination byte and stop processing
            } else if (hexBytes[i] == 0x03) {
                tempBytes[tempIndex] = bytes1(uint8(0x2e)); // Replace ETX with dot
            } else {
                tempBytes[tempIndex] = hexBytes[i];
            }
            tempIndex++;
        }

        // Create the final bytes array with the exact length of valid characters
        bytes memory strBytes = new bytes(tempIndex);
        for (uint256 j = 0; j < tempIndex; j++) {
            strBytes[j] = tempBytes[j];
        }

        return string(strBytes);
    }

    function supportsInterface(bytes4 interfaceID) public pure returns (bool) {
        return interfaceID == type(IExtendedResolver).interfaceId || interfaceID == type(IERC165).interfaceId;
    }

    // Namehash functions
    function getLabelhash(string memory _label) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(_label));
    }

    function getNamehash(bytes32 _parentHash, string memory _label) private pure returns (bytes32) {
        bytes32 labelhash = keccak256(abi.encodePacked(_label));
        return keccak256(abi.encodePacked(_parentHash, labelhash));
    }

    function getTldNamehash(string memory _label) private pure returns (bytes32) {
        return getNamehash(bytes32(0), _label);
    }

    function getDomainNamehash(string memory _domain) private pure returns (bytes32) {
        bytes memory bytesDomain = bytes(_domain);
        uint256 length = bytesDomain.length;
        bytes32 node = 0;
        uint8 labelLength = 0;

        // use unchecked to save gas since we check for an underflow
        // and we check for the length before the loop
        unchecked {
            for (uint256 i = length - 1; i >= 0; i--) {
                if (bytesDomain[i] == ".") {
                    node = keccak256(abi.encodePacked(node, keccak(bytesDomain, i + 1, labelLength)));
                    labelLength = 0;
                } else {
                    labelLength += 1;
                }
                if (i == 0) {
                    break;
                }
            }
        }

        node = keccak256(abi.encodePacked(node, keccak(bytesDomain, 0, labelLength)));

        return node;
    }

    // BytesUtils functions
    function keccak(bytes memory self, uint256 offset, uint256 len) internal pure returns (bytes32 ret) {
        require(offset + len <= self.length);
        assembly {
            ret := keccak256(add(add(self, 32), offset), len)
        }
    }

    function namehash(bytes memory self, uint256 offset) internal pure returns (bytes32) {
        (bytes32 labelhash, uint256 newOffset) = readLabel(self, offset);
        if (labelhash == bytes32(0)) {
            require(offset == self.length - 1, "namehash: Junk at end of name");
            return bytes32(0);
        }
        return keccak256(abi.encodePacked(namehash(self, newOffset), labelhash));
    }

    function readLabel(bytes memory self, uint256 idx) internal pure returns (bytes32 labelhash, uint256 newIdx) {
        require(idx < self.length, "readLabel: Index out of bounds");
        uint256 len = uint256(uint8(self[idx]));
        if (len > 0) {
            labelhash = keccak(self, idx + 1, len);
        } else {
            labelhash = bytes32(0);
        }
        newIdx = idx + len + 1;
    }
}
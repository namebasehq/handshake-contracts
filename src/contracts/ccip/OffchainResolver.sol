// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IExtendedResolver.sol";
import "./SignatureVerifier.sol";
import "@ensdomains/ens-contracts/contracts/registry/ENS.sol";
import "src/interfaces/resolvers/ITextResolver.sol";

/**
 * Implements an ENS resolver that directs all queries to a CCIP read gateway.
 * Callers must implement EIP 3668 and ENSIP 10.
 */
contract OffchainResolver is IExtendedResolver, IERC165, ITextResolver, Ownable {

    ENS public immutable ens;

    /**
     * A mapping of authorisations. An address that is authorised for a name
     * may make any changes to the name that the owner could, but may not update
     * the set of authorisations.
     * (node, owner, caller) => isAuthorised
     */
    mapping(bytes32=>mapping(address=>mapping(address=>bool))) public authorisations;

    mapping(bytes32=>mapping(string=>string)) public text;

    event AuthorisationChanged(bytes32 indexed node, address indexed owner, address indexed target, bool isAuthorised);

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

    function isAuthorised(bytes32 node) internal view returns(bool) {
        address owner = ens.owner(node);
        return owner == msg.sender || authorisations[node][owner][msg.sender];
    }

    string public url;
    mapping(address => bool) public signers;

    event NewSigners(address indexed signer, bool isSigner);
    event UpdateUrl(string url);

    error OffchainLookup(
        address sender,
        string[] urls,
        bytes callData,
        bytes4 callbackFunction,
        bytes extraData
    );

    error Unauthorized();
    error InvalidSignature();

    constructor(string memory _url, address[] memory _signers, address _ens) {
        url = _url;
        emit UpdateUrl(_url);

        ens = ENS(_ens);

        uint256 arrayLength = _signers.length;
        for (uint256 i; i < arrayLength; ) {
            signers[_signers[i]] = true;
            emit NewSigners(_signers[i], true);

            unchecked {
                ++i;
            }
        }
    }

    function makeSignatureHash(
        address target,
        uint64 expires,
        bytes memory request,
        bytes memory result
    ) external pure returns (bytes32) {
        return SignatureVerifier.makeSignatureHash(target, expires, request, result);
    }

    function setText(bytes32 node, string calldata key, string calldata value) external {
        if(!isAuthorised(node)) {
            revert Unauthorized();
        }
        
        text[node][key] = value;
        emit TextChanged(node, key, key, value);
    }

    /**
     * Resolves a name, as specified by ENSIP 10 (wildcard).
     * @param name The DNS-encoded name to resolve.
     * @param data The ABI encoded data for the underlying resolution function (Eg, addr(bytes32), text(bytes32,string), etc).
     * @return The return data, ABI encoded identically to the underlying function.
     */
    function resolve(bytes calldata name, bytes calldata data)
        external
        view
        override
        returns (bytes memory)
    {
        bytes memory callData = abi.encodeWithSelector(
            IExtendedResolver.resolve.selector,
            name,
            data
        );
        string[] memory urls = new string[](1);
        urls[0] = url;

        // revert with the OffchainLookup error, which will be caught by the client
        revert OffchainLookup(
            address(this),
            urls,
            callData,
            OffchainResolver.resolveWithProof.selector,
            callData
        );
    }

    function updateSigners(address[] calldata _signers, bool[] calldata _isSigner)
        external
        onlyOwner
    {
        for (uint256 i; i < _signers.length; i++) {
            signers[_signers[i]] = _isSigner[i];
            emit NewSigners(_signers[i], _isSigner[i]);
        }
    }

    function updateUrl(string calldata _url) external onlyOwner {
        url = _url;
        emit UpdateUrl(_url);
    }

    /**
     * Callback used by CCIP read compatible clients to verify and parse the response.
     */
    function resolveWithProof(bytes calldata response, bytes calldata extraData)
        external
        view
        returns (bytes memory)
    {
        (address signer, bytes memory result) = SignatureVerifier.verify(extraData, response);

        if(!signers[signer]) {
            revert InvalidSignature();
        }

        return result;
    }

    function supportsInterface(bytes4 interfaceID) public pure returns (bool) {
        return
            interfaceID == type(IExtendedResolver).interfaceId ||
            interfaceID == type(ITextResolver).interfaceId ||
            interfaceID == type(IERC165).interfaceId;
    }
}
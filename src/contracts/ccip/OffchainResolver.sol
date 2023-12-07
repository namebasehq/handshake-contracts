// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IExtendedResolver.sol";
import "./SignatureVerifier.sol";
import {IENS, INameWrapper} from "./EnsInterfaces.sol";

/**
 * Implements an ENS resolver that directs all queries to a CCIP read gateway.
 * Callers must implement EIP 3668 and ENSIP 10.
 */
contract OffchainResolver is IExtendedResolver, IERC165, Ownable {
    string public url;
    mapping(address => bool) public signers;

    event NewSigners(address indexed signer, bool isSigner);
    event UpdateUrl(string url);

    error Unauthorized();
    error InvalidSignature();
    error SelfApproval();

    // Logged when an operator is added or removed.
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    // Logged when a delegate is approved or  an approval is revoked.
    event Approved(
        address owner,
        bytes32 indexed node,
        address indexed delegate,
        bool indexed approved
    );

    /**
     * A mapping of operators. An address that is authorised for an address
     * may make any changes to the name that the owner could, but may not update
     * the set of authorisations.
     * (owner, operator) => approved
     */
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /**
     * A mapping of delegates. A delegate that is authorised by an owner
     * for a name may make changes to the name's resolver, but may not update
     * the set of token approvals.
     * (owner, name, delegate) => approved
     */
    mapping(address => mapping(bytes32 => mapping(address => bool))) private _tokenApprovals;

    // mainnet - 0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85
    address public immutable ENS_ADDRESS;

    address public immutable NAMEWRAPPER_ADDRESS;

    error OffchainLookup(
        address sender,
        string[] urls,
        bytes callData,
        bytes4 callbackFunction,
        bytes extraData
    );

    constructor(
        string memory _url,
        address[] memory _signers,
        address _ensAddress,
        address _namewrapperAddress
    ) {
        url = _url;
        emit UpdateUrl(_url);

        uint256 arrayLength = _signers.length;
        for (uint256 i; i < arrayLength; i++) {
            signers[_signers[i]] = true;
            emit NewSigners(_signers[i], true);
        }

        ENS_ADDRESS = _ensAddress;
        NAMEWRAPPER_ADDRESS = _namewrapperAddress;
    }

    function makeSignatureHash(
        address target,
        uint64 expires,
        bytes memory request,
        bytes memory result
    ) external pure returns (bytes32) {
        return SignatureVerifier.makeSignatureHash(target, expires, request, result);
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
        for (uint256 i = 0; i < _signers.length; i++) {
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

        if (!signers[signer]) {
            revert InvalidSignature();
        }

        return result;
    }

    function supportsInterface(bytes4 interfaceID) public pure returns (bool) {
        return
            interfaceID == type(IExtendedResolver).interfaceId ||
            interfaceID == type(IERC165).interfaceId;
    }

    /**
     * @dev See {IERC1155-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) external {
        if (msg.sender == operator) {
            revert SelfApproval();
        }

        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /**
     * @dev See {IERC1155-isApprovedForAll}.
     */
    function isApprovedForAll(address account, address operator) public view returns (bool) {
        return _operatorApprovals[account][operator];
    }

    /**
     * @dev Approve a delegate to be able to updated records on a node.
     */
    function approve(bytes32 node, address delegate, bool approved) external {
        if (msg.sender == delegate) {
            revert SelfApproval();
        }

        _tokenApprovals[msg.sender][node][delegate] = approved;
        emit Approved(msg.sender, node, delegate, approved);
    }

    /**
     * @dev Check to see if the delegate has been approved by the owner for the node.
     */
    function isApprovedFor(address owner, bytes32 node, address delegate)
        public
        view
        returns (bool)
    {
        return _tokenApprovals[owner][node][delegate];
    }

    modifier authorised(bytes32 node) {
        if (!isAuthorised(node)) {
            revert Unauthorized();
        }
        _;
    }

    function isAuthorised(bytes32 node) internal view returns (bool) {
        address owner = IENS(ENS_ADDRESS).owner(node);

        if (owner == NAMEWRAPPER_ADDRESS) {
            owner = INameWrapper(NAMEWRAPPER_ADDRESS).ownerOf(uint256(node));
        }

        return
            owner == msg.sender ||
            isApprovedForAll(owner, msg.sender) ||
            isApprovedFor(owner, node, msg.sender);
    }
}

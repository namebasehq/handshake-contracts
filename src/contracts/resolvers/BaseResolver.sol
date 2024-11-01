// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "interfaces/resolvers/IVersionableResolver.sol";
import "contracts/HandshakeNft.sol";

abstract contract BaseResolver is ERC165, IVersionableResolver {
    HandshakeNft internal immutable sldContract;
    HandshakeNft internal immutable tldContract;

    mapping(bytes32 => uint256) public recordVersions;

    // owner => tokenId => delegate
    mapping(address => mapping(uint256 => address)) public delegates;

    event UpdatedDelegate(address indexed _owner, uint256 indexed _tokenId, address _delegate);

    constructor(HandshakeNft _tld, HandshakeNft _sld) {
        sldContract = _sld;
        tldContract = _tld;
    }

    function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool) {
        return _interfaceId == type(IVersionableResolver).interfaceId || super.supportsInterface(_interfaceId);
    }

    // we can use this nonce to invalidate all records for a given node
    // with a single transaction
    function incrementVersion(bytes32 _nodehash) public virtual authorised(_nodehash) {
        unchecked {
            recordVersions[_nodehash]++;
        }
        emit VersionChanged(_nodehash, recordVersions[_nodehash]);
    }

    function setDelegate(uint256 _id, address _delegate) public {
        // delegate can't be transferred by the delegate
        require(
            sldContract.isApprovedOrOwner(msg.sender, _id) || tldContract.isApprovedOrOwner(msg.sender, _id),
            "not authorised or owner"
        );

        address owner = getTokenOwner(_id);
        emit UpdatedDelegate(owner, _id, _delegate);
        delegates[owner][_id] = _delegate;
    }

    function getTokenOwner(uint256 _id) public view returns (address) {
        if (sldContract.exists(_id)) {
            return sldContract.ownerOf(_id);
        }

        if (tldContract.exists(_id)) {
            return tldContract.ownerOf(_id);
        }

        revert("query for none existing token");
    }

    function getResolver(bytes32 node) internal view returns (IResolver) {
        uint256 id = uint256(node);

        if (sldContract.exists(id)) {
            return sldContract.tokenResolverMap(node);
        }

        if (tldContract.exists(id)) {
            return tldContract.tokenResolverMap(node);
        }

        return IResolver(address(0));
    }

    function ownerOf(bytes32 _node) internal view returns (address) {
        uint256 id = uint256(_node);

        if (sldContract.exists(id)) {
            return sldContract.ownerOf(id);
        }

        if (tldContract.exists(id)) {
            return tldContract.ownerOf(id);
        }

        revert("query for none existing token");
    }

    modifier authorised(bytes32 _nodehash) {
        uint256 id = uint256(_nodehash);

        require(
            sldContract.isApprovedOrOwner(msg.sender, id) || tldContract.isApprovedOrOwner(msg.sender, id)
                || delegates[getTokenOwner(id)][id] == msg.sender,
            "not authorised or owner"
        );
        _;
    }
}

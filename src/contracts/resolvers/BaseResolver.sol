// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "interfaces/resolvers/IVersionableResolver.sol";
import "contracts/HandshakeNft.sol";

abstract contract BaseResolver is ERC165, IVersionableResolver {
    HandshakeNft internal immutable sldContract;
    HandshakeNft internal immutable tldContract;

    mapping(bytes32 => uint256) public recordVersions;

    constructor(HandshakeNft _tld, HandshakeNft _sld) {
        sldContract = _sld;
        tldContract = _tld;
    }

    function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool) {
        return
            _interfaceId == type(IVersionableResolver).interfaceId ||
            super.supportsInterface(_interfaceId);
    }

    function incrementVersion(bytes32 _nodehash) public virtual authorised(_nodehash) {
        unchecked {
            recordVersions[_nodehash]++;
        }
    }

    modifier authorised(bytes32 _nodehash) {
        uint256 id = uint256(_nodehash);
        require(
            sldContract.isApprovedOrOwner(msg.sender, id) ||
                tldContract.isApprovedOrOwner(msg.sender, id),
            "not authorised or owner"
        );
        _;
    }
}

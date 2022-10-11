// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "interfaces/resolvers/IVersionableResolver.sol";
import "contracts/HandshakeNft.sol";

abstract contract BaseResolver is ERC165, IVersionableResolver {
    HandshakeNft internal immutable SldContract;
    HandshakeNft internal immutable TldContract;

    mapping(bytes32 => uint256) public recordVersions;

    constructor(HandshakeNft _tld, HandshakeNft _sld) {
        SldContract = _sld;
        TldContract = _tld;
    }

    function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool) {
        return
            _interfaceId == type(IVersionableResolver).interfaceId ||
            super.supportsInterface(_interfaceId);
    }

    function incrementVersion(bytes32 _nodehash) public authorised(_nodehash) {
        unchecked {
            recordVersions[_nodehash]++;
        }
    }

    modifier authorised(bytes32 _nodehash) {
        uint256 id = uint256(_nodehash);
        require(
            SldContract.isApprovedOrOwner(msg.sender, id) ||
                TldContract.isApprovedOrOwner(msg.sender, id),
            "not authorised or owner"
        );
        _;
    }
}

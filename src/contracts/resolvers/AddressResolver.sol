// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "interfaces/resolvers/IAddressResolver.sol";
import "interfaces/resolvers/IAddrResolver.sol";
import "contracts/resolvers/BaseResolver.sol";

abstract contract AddressResolver is IAddressResolver, IAddrResolver, BaseResolver {
    uint256 private constant ETH_COINTYPE = 60;

    mapping(uint256 => mapping(bytes32 => mapping(uint256 => bytes))) versionable_addresses;

    function addr(bytes32 _node, uint256 _coinType) public view returns (bytes memory) {
        bytes memory addr = versionable_addresses[recordVersions[_node]][_node][_coinType];

        if (keccak256(addr) == keccak256(bytes(""))) {
            return abi.encodePacked(ownerOf(_node));
        } else {
            return addr;
        }
    }

    function addr(bytes32 _node) public view returns (address payable) {
        address addr = bytesToAddress(addr(_node, ETH_COINTYPE));
        return payable(addr);
    }

    function setAddress(bytes32 _node, address _addr) public authorised(_node) {
        setAddress(_node, abi.encodePacked(_addr), ETH_COINTYPE);
    }

    function setAddress(bytes32 _node, bytes memory _addr, uint256 _cointype)
        public
        authorised(_node)
    {
        versionable_addresses[recordVersions[_node]][_node][_cointype] = _addr;

        emit AddrChanged(_node, bytesToAddress(_addr));
        emit AddressChanged(_node, _cointype, addr(_node, _cointype));
    }

    function incrementVersion(bytes32 _node) public virtual override authorised(_node) {
        address oldAddress = addr(_node);

        super.incrementVersion(_node);

        address newAddress = addr(_node);

        if (newAddress != oldAddress) {
            emit AddrChanged(_node, newAddress);
            emit AddressChanged(_node, 60, addr(_node, 60));
        }
    }

    function emitEvents(bytes32 _node) public authorised(_node) {
        emit AddrChanged(_node, addr(_node));
        emit AddressChanged(_node, 60, addr(_node, 60));
    }

    function bytesToAddress(bytes memory _b) private pure returns (address _addr) {
        assembly {
            _addr := mload(add(_b, 20))
        }
    }

    function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool) {
        return
            _interfaceId == type(IAddressResolver).interfaceId ||
            _interfaceId == type(IAddrResolver).interfaceId ||
            super.supportsInterface(_interfaceId);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "interfaces/resolvers/IAddressResolver.sol";
import "interfaces/resolvers/IAddrResolver.sol";
import "contracts/resolvers/BaseResolver.sol";

abstract contract AddressResolver is IAddressResolver, IAddrResolver, BaseResolver {
    uint256 private constant ETH_COINID = 60;
    uint256 private constant OPT_COINID = 614;
    uint256 private constant BSC_COINID = 9006;
    uint256 private constant MATIC_COINID = 966;
    uint256 private constant ARB_COINID = 9001;
    uint256 private constant AVAX_COINID = 9000;
    uint256 private constant AVAXC_COINID = 9005;

    mapping(uint256 => bool) public defaultCoinTypes;

    constructor() {
        defaultCoinTypes[ETH_COINID] = true;
        defaultCoinTypes[OPT_COINID] = true;
        defaultCoinTypes[BSC_COINID] = true;
        defaultCoinTypes[MATIC_COINID] = true;
        defaultCoinTypes[ARB_COINID] = true;
        defaultCoinTypes[AVAX_COINID] = true;
        defaultCoinTypes[AVAXC_COINID] = true;
    }

    mapping(uint256 => mapping(bytes32 => mapping(address => mapping(uint256 => bytes)))) versionable_addresses;

    function addr(bytes32 _node, uint256 _coinType) public view returns (bytes memory) {
        address owner = ownerOf(_node);
        bytes memory addr1 = versionable_addresses[recordVersions[_node]][_node][owner][_coinType];

        if (keccak256(addr1) == keccak256(bytes("")) && defaultCoinTypes[_coinType]) {
            return abi.encodePacked(owner);
        } else {
            return addr1;
        }
    }

    function addr(bytes32 _node) public view returns (address payable) {
        address addr1 = bytesToAddress(addr(_node, OPT_COINID));
        return payable(addr1);
    }

    function setAddress(bytes32 _node, address _addr) public authorised(_node) {
        setAddress(_node, abi.encodePacked(_addr), OPT_COINID);
    }

    function setAddress(
        bytes32 _node,
        bytes memory _addr,
        uint256 _cointype
    ) public authorised(_node) {
        versionable_addresses[recordVersions[_node]][_node][ownerOf(_node)][_cointype] = _addr;

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

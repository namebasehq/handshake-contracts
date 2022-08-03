// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "interfaces/IResolver.sol";

contract Resolver is IResolver {
    address TldAddress;
    address SldAddress;

    constructor(address _sld, address _tld) {
        TldAddress = _tld;
        SldAddress = _sld;
    }

    function addr(bytes32 _namehash) external view returns (address payable) {}

    function contenthash(bytes32 _namehash) external view returns (bytes memory) {}

    function dnsRecord(
        bytes32 _namehash,
        bytes32 _name,
        uint16 _resource
    ) external view returns (bytes memory) {}

    function name(bytes32 _namehash) external view returns (string memory) {}

    function publickey(bytes32 _namehash) external view returns (bytes32 x, bytes32 y) {}

    function text(bytes32 _namehash, string calldata _key)
        external
        view
        returns (string memory)
    {}

    function setDnsRecord(
        bytes32 _namehash,
        bytes32 _name,
        uint16 _resource
    ) external isDomainContract returns (bytes memory) {}

    function setAddr(bytes32 _namehash, address addr) external isDomainContract {}

    function setContentHash(bytes32 _namehash, bytes calldata hash)
        external
        isDomainContract
    {}

    function setName(bytes32 _namehash, string calldata _name)
        external
        isDomainContract
    {}

    function setPublicKey(
        bytes32 _namehash,
        bytes32 x,
        bytes32 y
    ) external isDomainContract {}

    function setText(
        bytes32 _namehash,
        string calldata key,
        string calldata value
    ) external isDomainContract {}

    modifier isDomainContract() {
        require(msg.sender == SldAddress || msg.sender == TldAddress, "NOT AUTHORISED");
        _;
    }
}

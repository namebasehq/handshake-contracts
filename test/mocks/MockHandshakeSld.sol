// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "interfaces/IHandshakeSld.sol";
import "interfaces/ISldRegistrationStrategy.sol";

contract MockHandshakeSld is IHandshakeSld {
    mapping(uint256 => mapping(address => bool)) idToAddressToApproved;
    mapping(bytes32 => ISldRegistrationStrategy) mockRegistrationStrategy;
    mapping(bytes32 => bytes32) public namehashToParentMap;
    mapping(bytes32 => string) nodeToName;
    mapping(bytes32 => IResolver) public tokenResolverMap;

    uint256 public ExpiryTimestamp;

    string public ParentName;

    function isApprovedOrOwnerOfChildOrParent(uint256 _id) external view returns (bool) {
        return idToAddressToApproved[_id][msg.sender];
    }

    function burnSld(bytes32 _namehash) external {}

    function isApprovedOrOwner(
        address spender,
        uint256 tokenId
    ) public view override returns (bool) {
        return idToAddressToApproved[tokenId][spender];
    }

    function ownerOf(uint256) external pure returns (address) {
        return address(0x4);
    }

    function addMapping(uint256 _id, address _addr, bool _approved) public {
        idToAddressToApproved[_id][_addr] = _approved;
    }

    function namehashToLabelMap(bytes32 _childNamehash) external view returns (string memory) {}

    function registerSld(address _to, bytes32 _tldNamehash, string calldata _label) external {}

    function registrationStrategy(
        bytes32 _sldNamehash
    ) external view returns (ISldRegistrationStrategy) {}

    function getRegistrationStrategy(
        bytes32 _parentNamehash
    ) public view returns (ISldRegistrationStrategy) {
        return mockRegistrationStrategy[_parentNamehash];
    }

    function setResolver(bytes32 _namehash, IResolver _resolver) public {
        tokenResolverMap[_namehash] = _resolver;
    }

    function setMockRegistrationStrategy(
        bytes32 _parentNamehash,
        ISldRegistrationStrategy _strategy
    ) public {
        mockRegistrationStrategy[_parentNamehash] = _strategy;
    }

    function setNamehashToParentMap(bytes32 _childNamehash, bytes32 _parentNamehash) external {
        namehashToParentMap[_childNamehash] = _parentNamehash;
    }

    function setParent(string memory _name) public {
        ParentName = _name;
    }

    function parent(bytes32) public view returns (string memory _parentName) {
        _parentName = ParentName;
    }

    function setExpiry(uint256 _expiry) public {
        ExpiryTimestamp = _expiry;
    }

    function expiry(bytes32) public view override returns (uint256 _expiry) {
        _expiry = ExpiryTimestamp;
    }

    function name(bytes32 _namehash) external view override returns (string memory _name) {
        return nodeToName[_namehash];
    }

    function setName(bytes32 _namehash, string calldata _name) public {
        nodeToName[_namehash] = _name;
    }
}

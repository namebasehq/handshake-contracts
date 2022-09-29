// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "interfaces/IHandshakeSld.sol";
import "interfaces/ISldRegistrationStrategy.sol";

contract MockHandshakeSld is IHandshakeSld {
    mapping(uint256 => mapping(address => bool)) idToAddressToApproved;
    mapping(bytes32 => ISldRegistrationStrategy) mockRegistrationStrategy;
    mapping(bytes32 => bytes32) public namehashToParentMap;

    function isApprovedOrOwnerOfChildOrParent(uint256 _id) external view returns (bool) {
        return idToAddressToApproved[_id][msg.sender];
    }

    function isApprovedOrOwner(address spender, uint256 tokenId)
        public
        view
        override
        returns (bool)
    {
        return idToAddressToApproved[tokenId][spender];
    }

    function ownerOf(uint256 _id) external view returns (address) {
        return address(0x4);
    }

    function addMapping(
        uint256 _id,
        address _addr,
        bool _approved
    ) public {
        idToAddressToApproved[_id][_addr] = _approved;
    }

    function registerSld(
        address _to,
        bytes32 _tldNamehash,
        bytes32 _sldNamehash
    ) external {}

    function registrationStrategy(bytes32 _subdomainNamehash)
        external
        view
        returns (ISldRegistrationStrategy)
    {}

    function getRegistrationStrategy(bytes32 _parentNamehash)
        public
        view
        returns (ISldRegistrationStrategy)
    {
        return mockRegistrationStrategy[_parentNamehash];
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
}

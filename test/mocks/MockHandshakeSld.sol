// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "interfaces/IHandshakeSld.sol";

contract MockHandshakeSld is IHandshakeSld {
    mapping(uint256 => mapping(address => bool)) IdToAddressToApproved;

    function isApprovedOrOwnerOfChildOrParent(uint256 _id) external view returns (bool) {
        return IdToAddressToApproved[_id][msg.sender];
    }

    function isApprovedOrOwner(address spender, uint256 tokenId)
        public
        view
        override
        returns (bool)
    {
        return IdToAddressToApproved[tokenId][spender];
    }

    function addMapping(
        uint256 _id,
        address _addr,
        bool _approved
    ) public {
        IdToAddressToApproved[_id][_addr] = _approved;
    }

    
    function registerSld(address _to, bytes32 _tldNamehash, bytes32 _sldNamehash) external {
        
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "interfaces/ISldRegistrationStrategy.sol";
import "interfaces/IResolver.sol";

interface IHandshakeSld {
    function isApprovedOrOwner(address spender, uint256 tokenId) external view returns (bool);

    function registerSld(address _to, bytes32 _tldNamehash, string calldata _label) external;

    function ownerOf(uint256 _id) external view returns (address);

    function getRegistrationStrategy(bytes32 _parentNamehash)
        external
        view
        returns (ISldRegistrationStrategy);

    function namehashToParentMap(bytes32 _childNamehash)
        external
        view
        returns (bytes32 _parentNamehash);

    function name(bytes32 _sldNamehash) external view returns (string memory _fullDomain);

    function expiry(bytes32 _namehash) external view returns (uint256 _expiry);

    function parent(bytes32) external view returns (string memory _parentName);

    function namehashToLabelMap(bytes32 _childNamehash) external view returns (string memory);

    function burnSld(bytes32 _namehash) external;
}

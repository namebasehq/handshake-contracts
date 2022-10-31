// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "interfaces/ISldRegistrationStrategy.sol";

interface IHandshakeSld {
    function isApprovedOrOwner(address spender, uint256 tokenId) external view returns (bool);

    function registerSld(
        address _to,
        bytes32 _tldNamehash,
        string calldata _label
    ) external payable;

    function ownerOf(uint256 _id) external view returns (address);

    function getRegistrationStrategy(bytes32 _parentNamehash)
        external
        view
        returns (ISldRegistrationStrategy);

    function namehashToParentMap(bytes32 _childNamehash)
        external
        view
        returns (bytes32 _parentNamehash);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

interface IHandshakeSld {
    function isApprovedOrOwnerOfChildOrParent(uint256 _id) external returns (bool);
    function isApprovedOrOwner(address spender, uint256 tokenId) external view returns (bool);
}

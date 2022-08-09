// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.15;

interface IHandshakeSld {

    function isApprovedOrOwnerOfChildOrParent(uint256 _id) external returns (bool);
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

interface IHandshakeTld {
    function register(address _addr, string calldata _domain) external;
}

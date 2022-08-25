// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

interface IPriceOracle {
    function getPrice() external view returns (uint256);
}

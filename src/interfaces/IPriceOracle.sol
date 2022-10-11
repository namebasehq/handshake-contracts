// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IPriceOracle {
    function getPrice() external view returns (uint256);

    function getWeiValueOfDollar() external view returns (uint256);
}

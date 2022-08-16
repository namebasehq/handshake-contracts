//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "interfaces/IPriceOracle.sol";

contract MockUsdOracle is IPriceOracle {
    uint256 Price;

    constructor(uint256 _price) {
        //200000000000 - ($2000)
        Price = 200000000000;
    }

    function getPrice() external returns (uint256) {
        return Price;
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "interfaces/IPriceOracle.sol";

contract MockUsdOracle is IPriceOracle {
    uint256 Price;

    constructor(uint256 _price) {
        //200000000000 - ($2000)
        Price = _price;
    }

    function getPrice() public view returns (uint256) {
        return Price;
    }

    function getWeiValueOfDollar() public view returns (uint256) {
        uint256 price = getPrice();
        return (1 ether * 100000000) / price;
    }
}

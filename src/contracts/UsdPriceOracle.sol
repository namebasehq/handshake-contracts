//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "interfaces/IPriceOracle.sol";

contract UsdPriceOracle is IPriceOracle {
    AggregatorV3Interface internal immutable priceFeed;

    error InvalidPrice();

    constructor(address _oracle) {
        // goerli optimism - 0x57241A37733983F97C4Ab06448F244A1E0Ca0ba8
        priceFeed = AggregatorV3Interface(_oracle);
    }

    function getPrice() public view returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        if (price == 0) {
            revert InvalidPrice();
        }
        return uint256(price);
    }

    function getWeiValueOfDollar() public view returns (uint256) {
        uint256 price = getPrice();

        return (1 ether * 100000000) / price;
    }
}

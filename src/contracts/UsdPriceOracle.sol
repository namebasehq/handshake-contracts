//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "interfaces/IPriceOracle.sol";

contract UsdPriceOracle is IPriceOracle {
    AggregatorV3Interface internal priceFeed;

    constructor() {
        priceFeed = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
    }

    function getPrice() public view returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        require(price > 0, "oracle returned invalid price");
        return uint256(price);
    }
}

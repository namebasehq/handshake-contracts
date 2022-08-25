// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/Ownable.sol";
import "interfaces/IPriceOracle.sol";
import "src/contracts/UsdPriceOracle.sol";

pragma solidity ^0.8.15;

contract HasUsdOracle is Ownable {
    IPriceOracle public UsdOracle = new UsdPriceOracle();
    event NewUsdOracle(address indexed _usdEthPriceOracle);
}

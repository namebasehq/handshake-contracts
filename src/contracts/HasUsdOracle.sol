// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "interfaces/IPriceOracle.sol";
import "contracts/UsdPriceOracle.sol";

contract HasUsdOracle is Ownable {
    IPriceOracle public usdOracle = new UsdPriceOracle();
    event NewUsdOracle(address indexed _usdEthPriceOracle);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "interfaces/IPriceOracle.sol";

contract HasUsdOracle {
    IPriceOracle public usdOracle;

    event NewUsdOracle(address indexed _usdEthPriceOracle);
}

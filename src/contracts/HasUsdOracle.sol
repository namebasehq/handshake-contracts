// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "interfaces/IPriceOracle.sol";
import "contracts/UsdPriceOracle.sol";

contract HasUsdOracle {
    IPriceOracle public usdOracle;

    constructor(IPriceOracle _oracle) {
        usdOracle = _oracle;
    }

    event NewUsdOracle(address indexed _usdEthPriceOracle);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "interfaces/ISldRegistrationStrategy.sol";
import {console} from "forge-std/console.sol";

contract MockRevertingRegistrationStrategy is ISldRegistrationStrategy {
    function isDisabled(bytes32 _parentNamehash) external view returns (bool) {}

    function getPriceInDollars(address, bytes32, string memory, uint256, bool)
        external
        pure
        returns (uint256)
    {
        revert("MockRevertingRegistrationStrategy: revert");
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return
            interfaceId == type(ISldRegistrationStrategy).interfaceId ||
            interfaceId == type(IERC165).interfaceId ||
            interfaceId == this.getPriceInDollars.selector ||
            interfaceId == this.isDisabled.selector;
    }
}

contract MockGasLimitRegistrationStrategy is ISldRegistrationStrategy {
    uint256 gasLimit;

    constructor(uint256 _gasLimit) {
        gasLimit = _gasLimit;
    }

    function isDisabled(bytes32 _parentNamehash) external view returns (bool) {}

    function getPriceInDollars(address, bytes32, string memory, uint256, bool)
        external
        view
        returns (uint256)
    {
        //loop until certain gas limit is reached
        uint256 gasLeft = gasleft();
        uint256 target;

        if (gasLeft < gasLimit) {
            target = 0;
        } else {
            target = gasLeft - gasLimit;
        }

        while (gasleft() > target) {}

        return 12345 ether;
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return
            interfaceId == type(ISldRegistrationStrategy).interfaceId ||
            interfaceId == type(IERC165).interfaceId ||
            interfaceId == this.getPriceInDollars.selector ||
            interfaceId == this.isDisabled.selector;
    }
}

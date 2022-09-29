// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {console} from "forge-std/console.sol";

abstract contract PaymentManager {
    address public handshakeWalletPayoutAddress;

    constructor(address _handshakeWalletAddress) {
        handshakeWalletPayoutAddress = _handshakeWalletAddress;
    }

    function distributePrimaryFunds(
        address _sldOwner,
        address _tldOwner,
        uint256 _funds
    ) internal {
        uint256 contractFunds = address(this).balance;
        require(contractFunds >= _funds, "not enough ether");
        if (contractFunds > 0) {
            uint256 handshakeShare = (_funds * 5) / 100;

            payable(_tldOwner).transfer(_funds - handshakeShare);
            payable(handshakeWalletPayoutAddress).transfer(handshakeShare);

            if (contractFunds > _funds) {
                uint256 returnFunds = contractFunds - _funds;
                (bool success, ) = payable(msg.sender).call{value: returnFunds}("");
                if (!success) {
                    payable(_sldOwner).transfer(returnFunds);
                }
            }
        }
    }
}

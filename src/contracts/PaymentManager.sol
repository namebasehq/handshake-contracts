// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

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
        require(address(this).balance >= _funds, "not enough ether");
        if (address(this).balance > 0) {
            uint256 handshakeShare = (_funds * 5) / 100;

            if (address(this).balance > _funds) {
                payable(_sldOwner).transfer(address(this).balance - _funds);
            }

            payable(_tldOwner).transfer(_funds - handshakeShare);
            payable(handshakeWalletPayoutAddress).transfer(handshakeShare);
        }
    }
}

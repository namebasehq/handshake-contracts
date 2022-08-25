// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

contract PaymentManager {
    address public HandshakeWalletPayoutAddress;

    constructor(address _handshakeWalletAddress) {
        HandshakeWalletPayoutAddress = _handshakeWalletAddress;
    }

    function distributePrimaryFunds(address _tldOwner, uint256 _funds) internal {
        if (msg.value > 0) {
            uint256 handshakeShare = (_funds * 5) / 100;

            payable(_tldOwner).transfer(_funds - handshakeShare);
            payable(HandshakeWalletPayoutAddress).transfer(handshakeShare);
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 *
 * @title Handshake Payment Manager
 * @author hodl.esf.eth
 */
abstract contract PaymentManager {
    address public handshakeWalletPayoutAddress;
    uint256 public handshakePercentCommission;

    event PaymentSent(address indexed _to, uint256 _amount);

    /**
     * Sends the primary funds to the specified owners and the handshake wallet
     *
     * @param _sldOwner The owner of the SLD
     * @param _tldOwner The owner of the TLD
     * @param _funds The amount of funds to be distributed
     */
    function distributePrimaryFunds(address _sldOwner, address _tldOwner, uint256 _funds) internal {
        require(msg.value >= _funds, "not enough ether");

        uint256 handshakeShare = (_funds * handshakePercentCommission) / 100;

        bool isSent;

        // send any surplus funds back to the SLD owner
        if (msg.value > _funds) {
            uint256 excess = msg.value - _funds;
            isSent = payable(_sldOwner).send(excess);

            if (isSent){
                emit PaymentSent(_sldOwner, excess);
            }
        }

        // if there is a failure to send ether then the funds will just get sent to the handshake wallet
        // this is done to prevent a malicious TLD owner from blocking renewals

        uint256 primary = _funds - handshakeShare;
        isSent = payable(_tldOwner).send(primary);

        if (isSent){
            emit PaymentSent(_tldOwner, _funds - handshakeShare);
        }

        uint256 remaining = address(this).balance;
        bool result = payable(handshakeWalletPayoutAddress).send(remaining);


        emit PaymentSent(handshakeWalletPayoutAddress, remaining);


        // revert if the transfer failed and funds sat in the contract
        require(result, "transfer failed");
    }
}

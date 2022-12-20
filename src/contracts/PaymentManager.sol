// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 *
 * @title Handshake Payment Manager
 * @author hodl.esf.eth
 */
abstract contract PaymentManager {
    address public handshakeWalletPayoutAddress;

    /**
     * Sends the primary funds to the specified owners and the handshake wallet
     *
     * @param _sldOwner The owner of the SLD
     * @param _tldOwner The owner of the TLD
     * @param _funds The amount of funds to be distributed
     */
    function distributePrimaryFunds(address _sldOwner, address _tldOwner, uint256 _funds) internal {
        require(address(this).balance >= _funds, "not enough ether");

        uint256 handshakeShare = (_funds * 5) / 100;

        // send any surplus funds back to the SLD owner
        if (address(this).balance > _funds) {
            payable(_sldOwner).send(address(this).balance - _funds);
        }

        // if there is a failure to send ether then the funds will just get sent to the handshake wallet
        // this is done to prevent a malicious TLD owner from blocking renewals

        payable(_tldOwner).send(_funds - handshakeShare);

        bool result = payable(handshakeWalletPayoutAddress).send(address(this).balance);

        // revert if the transfer failed and funds sat in the contract
        require(result, "transfer failed");
    }
}

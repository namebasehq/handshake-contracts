// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 *
 * @title Handshake Payment Manager
 * @author hodl.esf.eth
 */
abstract contract PaymentManager {
    //slither-disable-start immutable-states
    //slither-disable-start constable-states
    address public feeWalletPayoutAddress;
    uint256 public percentCommission;

    //slither-disable-end constable-states
    //slither-disable-end immutable-states

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

        uint256 handshakeShare = (_funds * percentCommission) / 100;

        require(_funds > handshakeShare, "not enough funds to pay commission");

        uint256 primary = _funds - handshakeShare;
        uint256 excess = msg.value - _funds;

        bool isSent;

        // send any surplus funds back to the SLD owner
        if (excess > 0) {
            (isSent,) = payable(_sldOwner).call{value: excess, gas: 50_000}("");
        }

        // if there is a failure to send ether then the funds will just get sent to the handshake wallet
        // this is done to prevent a malicious TLD owner from blocking renewals

        (isSent,) = payable(_tldOwner).call{value: primary, gas: 50_000}("");

        if (isSent) {
            emit PaymentSent(_tldOwner, primary);
        }

        uint256 remaining = address(this).balance;
        if (remaining > 0) {
            (bool result,) = payable(feeWalletPayoutAddress).call{value: remaining}("");
            emit PaymentSent(feeWalletPayoutAddress, remaining);

            // revert if the transfer failed and funds sat in the contract
            require(result, "transfer failed");
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * Payment errors can be used by TLD Manager and PaymentManager contracts
 * @title Handshake Payment Errors
 * @author hodl.esf.eth
 */
abstract contract PaymentErrors {
    error InsufficientFunds();
    error TransferFailed();

    event PaymentSent(address indexed _to, uint256 _amount);
}

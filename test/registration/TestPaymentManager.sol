// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

import "contracts/PaymentManager.sol";

contract PaymentManagerForTesting is PaymentManager {
    constructor(address _paymentWallet) PaymentManager(_paymentWallet) {}

    function payableFunction(
        address _sldOwner,
        address _tldOwner,
        uint256 _funds
    ) external payable {
        distributePrimaryFunds(_sldOwner, _tldOwner, _funds);
    }
}

contract TestPaymentManager is Test {
    PaymentManagerForTesting private paymentManager;
    address private payoutAddress;

    function setUp() public {
        payoutAddress = address(0x1337);
        paymentManager = new PaymentManagerForTesting(payoutAddress);
    }

    function testPayoutSplitCorrectly() public {
        uint256 totalFunds = 10 ether;
        uint256 spentFunds = 4 ether;

        address tldOwner = address(0x22);
        address sldOwner = address(0x88);
        address sender = address(0x420);

        paymentManager.payableFunction{value: totalFunds}(sldOwner, tldOwner, spentFunds);

        uint256 onePercent = spentFunds / 100;

        assertEq(address(paymentManager).balance, 0, "balance of contract should be zero");
        assertEq(payoutAddress.balance, onePercent * 5, "payout wallet should get 5% of funds");
        assertEq(sender.balance, 0, "balance of sender should be zero");
        assertEq(
            sldOwner.balance,
            totalFunds - spentFunds,
            "balance of sldOwner should be returned overspend"
        );
        assertEq(tldOwner.balance, onePercent * 95, "tld owner wallet should get 95% of the funds");
    }
}

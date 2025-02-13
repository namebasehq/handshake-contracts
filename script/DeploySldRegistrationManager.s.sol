// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "contracts/SldRegistrationManager.sol";

// forge script script/DeploySldRegistrationManager.s.sol:UpgradeScript --rpc-url $OPT_TEST_RPC --private-key $PROXY_OWNER_PRIVATE_KEY --broadcast

// old sepolia implementation contract 0x5c1C80d89d6Aaa541720421e797194B2F9D8ED7d
contract UpgradeScript is Script {
    // The address of the proxy we want to upgrade
    address private constant PROXY_ADDRESS = 0x529B2b5B576c27769Ae0aB811F1655012f756C00;

    function setUp() public {}

    function run2() public {
        // Get the proxy owner's private key from env
        uint256 proxyOwnerKey = vm.envUint("PROXY_OWNER_PRIVATE_KEY");

        vm.startBroadcast(proxyOwnerKey);

        // 1. Deploy new implementation
        SldRegistrationManager newImplementation = new SldRegistrationManager();
        console.log("New implementation deployed at:", address(newImplementation));

        // 2. Get proxy admin interface
        ITransparentUpgradeableProxy proxy = ITransparentUpgradeableProxy(PROXY_ADDRESS);

        // 3. Upgrade to new implementation
        proxy.upgradeTo(address(newImplementation));
        console.log("Proxy upgraded to new implementation");
        vm.stopBroadcast();

        vm.startPrank(SldRegistrationManager(address(proxy)).owner());

        console.log("owner: ", SldRegistrationManager(address(proxy)).owner());

        SldRegistrationManager(address(proxy)).updatePaymentPercent(5);

        uint256 paymentPercent = SldRegistrationManager(address(proxy)).percentCommission();
        address paymentAddress = SldRegistrationManager(address(proxy)).feeWalletPayoutAddress();

        console.log("Payment percent is now:", paymentPercent);
        console.log("Payment address is now:", paymentAddress);
    }

    function run() public {
        uint256 ownerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(ownerKey);

        SldRegistrationManager manager = SldRegistrationManager(PROXY_ADDRESS);

        manager.updatePaymentPercent(5);

        uint256 paymentPercent = SldRegistrationManager(PROXY_ADDRESS).percentCommission();
        address paymentAddress = SldRegistrationManager(PROXY_ADDRESS).feeWalletPayoutAddress();

        console.log("Payment percent is now:", paymentPercent);
        console.log("Payment address is now:", paymentAddress);
    }
}

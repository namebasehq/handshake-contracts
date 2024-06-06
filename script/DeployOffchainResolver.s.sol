//0x9b6435e0e73d40f8a64fe5094e4ea462a54a078b

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import "contracts/GlobalRegistrationRules.sol";
import "contracts/HandshakeSld.sol";
import "contracts/HandshakeTld.sol";
import "contracts/LabelValidator.sol";
import "contracts/metadata/GenericMetadata.sol";
import "contracts/SldCommitIntent.sol";
import "contracts/SldRegistrationManager.sol";
import "contracts/DefaultRegistrationStrategy.sol";
import "contracts/TldClaimManager.sol";
import "contracts/UsdPriceOracle.sol";
import "mocks/MockUsdOracle.sol";
import "contracts/resolvers/DefaultResolver.sol";
import "interfaces/IPriceOracle.sol";
import "test/mocks/TestingRegistrationStrategy.sol";
import "src/contracts/ccip/OffchainResolver.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployOffchainResolverScript is Script {
    function setUp() public {


    }

    function run() public {

        // forge script script/DeployOffchainResolver.s.sol:DeployOffchainResolverScript --private-key $GOERLI_DEPLOYER_PRIVATE_KEY --rpc-url $RPC_URL --broadcast -vv


        vm.startBroadcast(vm.envUint("GOERLI_DEPLOYER_PRIVATE_KEY"));

        string memory url = "https://hns-id-git-ccip-dns-gasfree-update-namebase.vercel.app/api/gateway/ccip?data={data}&sender={sender}";

        address[] memory signers = new address[](1);

        signers[0] = 0x9b6435E0E73d40F8A64fE5094e4ea462a54a078B;

        address ens = address(0x1);
  
        // Deploy the off-chain resolver
        OffchainResolver offchainResolver = new OffchainResolver(url, signers, ens);

        console.log("OffchainResolver deployed at: ", address(offchainResolver));


    }
}

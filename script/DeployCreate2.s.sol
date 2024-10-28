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
import "src/contracts/Factory.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployCreate2Script is Script {
    Factory create2Factory;

    function setUp() public {
        create2Factory = Factory(0x399FD7143b07689e7014270720aa861e1E48cEDA);
    }

    function run() public {
        vm.startBroadcast(vm.envUint("GOERLI_DEPLOYER_PRIVATE_KEY"));
        deploy1();
        vm.stopBroadcast();

        // getHashes();
    }

    function getHashes() public {
        address oracleAddress = 0x57241A37733983F97C4Ab06448F244A1E0Ca0ba8;

        bytes32 tld = keccak256(type(HandshakeTld).creationCode);
        bytes32 priceOracle = keccak256(getCodeAndArgs(type(UsdPriceOracle).creationCode, abi.encode(oracleAddress)));
        bytes32 labelValidator = keccak256(type(LabelValidator).creationCode);
        bytes32 globalRegistrationRules = keccak256(type(GlobalRegistrationRules).creationCode);
        bytes32 commitIntent = keccak256(type(SldCommitIntent).creationCode);
        bytes32 registrationManager = keccak256(type(SldRegistrationManager).creationCode);
        bytes32 claimManager = keccak256(type(TldClaimManager).creationCode);

        console.logBytes32(tld);
        console.logBytes32(priceOracle);
        console.logBytes32(labelValidator);
        console.logBytes32(globalRegistrationRules);
        console.logBytes32(commitIntent);
        console.logBytes32(registrationManager);
        console.logBytes32(claimManager);
    }

    function deploy1() private {
        address oracleAddress = 0x57241A37733983F97C4Ab06448F244A1E0Ca0ba8;

        bytes memory tld = type(HandshakeTld).creationCode;
        bytes memory priceOracle = getCodeAndArgs(type(UsdPriceOracle).creationCode, abi.encode(oracleAddress));
        bytes memory labelValidator = type(LabelValidator).creationCode;
        bytes memory globalRegistrationRules = type(GlobalRegistrationRules).creationCode;
        bytes memory commitIntent = type(SldCommitIntent).creationCode;
        bytes memory registrationManager = type(SldRegistrationManager).creationCode;
        bytes memory claimManager = type(TldClaimManager).creationCode;

        uint256 a = 0xd3d701a25177767d9515d24bae33f2dc7a5d5eeffa0f594e717ae80086ce59cd; // => 0x00000000bc0B1773a3c3dDC02dF402d31bDe6786 => 256 (4 / 4)
        uint256 b = 0xd3d701a25177767d9515d24bae33f2dc7a5d5eeff4fe525e12daf4034b2a609f; //  => 0x0000000035F8B214E400DA2F04EFF8dd0aF648F2 => 4217 (4 / 5)
        uint256 c = 0xd3d701a25177767d9515d24bae33f2dc7a5d5eefcd07d0dd9f193601fdba008c; //  => 0x00000000F28358E9e2B2814f27ffE75b36328b5D => 256 (4 / 4)
        uint256 d = 0xd3d701a25177767d9515d24bae33f2dc7a5d5eefebee4b749df1d2020dd6f80d; //  => 0x00000000E9b9aADC80f7DfC430f2c5C35BbBBf97 => 256 (4 / 4)
        uint256 e = 0xd3d701a25177767d9515d24bae33f2dc7a5d5eef8820a78db4a1e20040daf114; //  => 0x00000000dF9C7d2cCd67a2004Bc96F508558Fc70 => 4217 (4 / 5)
        uint256 f = 0xd3d701a25177767d9515d24bae33f2dc7a5d5eef5785e8a6d2d318013795ea8b; //  => 0x00000000d0ee9B67946594d5ea082422f63Ec341 => 256 (4 / 4)
        uint256 g = 0xd3d701a25177767d9515d24bae33f2dc7a5d5eef9f1c682c8c504501e6ced201; //  => 0x00000000172932a973d56C7A0038dA41d0558EB2 => 4217 (4 / 5)

        create2Factory.deploy(tld, a);
        // create2Factory.deploy(priceOracle, b);
        // create2Factory.deploy(labelValidator, c);
        // create2Factory.deploy(globalRegistrationRules, d);
        // create2Factory.deploy(commitIntent, e);
        // create2Factory.deploy(registrationManager, f);
        // create2Factory.deploy(claimManager, g);
    }

    // function deploy2() private {

    //     address sldRegistrationManagerAddress = address(0);
    //     address signerAddress = address(0);
    //     address resolverAddress = address(0);
    //     address tld = address(0);

    //     HandshakeSld sld = new HandshakeSld(HandshakeTld(tld));

    //     GenericMetadataService metadata = new GenericMetadataService(sld, HandshakeTld(tld), baseUri);

    //     DefaultResolver resolver = new DefaultResolver(tld, sld);

    //         tld.setMetadataContract(metadata);
    //         sld.setMetadataContract(metadata);

    //             TransparentUpgradeableProxy uups2 = new TransparentUpgradeableProxy(
    //         sldRegistrationManagerAddress,
    //         deployerWallet,
    //         abi.encodeWithSelector(
    //             SldRegistrationManager.init.selector,
    //             tld,
    //             sld,
    //             commitIntent,
    //             priceOracle,
    //             labelValidator,
    //             globalRules,
    //             ownerWallet,
    //             ownerWallet
    //         )
    //     );

    //             TransparentUpgradeableProxy uups = new TransparentUpgradeableProxy(
    //         address(new TldClaimManager()),
    //         deployerWallet,
    //         abi.encodeWithSelector(
    //             TldClaimManager.init.selector,
    //             labelValidator,
    //             ownerWallet,
    //             tld,
    //             strategy,
    //             priceOracle,
    //             100 ether,
    //             ownerWallet
    //         )
    //     );

    //                SldRegistrationManager(sldRegistrationManagerAddress).updateSigner(
    //             signerAddress,
    //             true
    //         );

    //     sld.setRegistrationManager(SldRegistrationManager(address(uups2)));

    //     //transfer ownership of ownable contracts
    //     sld.setDefaultResolver(IResolver(resolverAddress));
    //     tld.setDefaultResolver(IResolver(resolverAddress));

    //     //registrationManager.transferOwnership(ownerWallet);
    //     sld.transferOwnership(ownerWallet);
    //     tld.transferOwnership(ownerWallet);
    //     commitIntent.transferOwnership(ownerWallet);

    //     SldRegistrationManager(address(uups2)).updatePaymentPercent(5);
    // }

    // function deploy3() public {

    //     address sldRegistrationManagerAddress = address(0);

    //     DefaultRegistrationStrategy strategy = new DefaultRegistrationStrategy(
    //         sldRegistrationManagerAddress
    //     );

    // }

    function getCodeAndArgs(bytes memory code, bytes memory args) private pure returns (bytes memory) {
        return abi.encodePacked(code, args);
    }
}

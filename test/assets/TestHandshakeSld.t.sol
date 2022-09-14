// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import { Namehash } from "utils/Namehash.sol";
import "contracts/HandshakeSld.sol";
import "utils/Namehash.sol";
import "interfaces/ITldClaimManager.sol";
import "test/mocks/MockClaimManager.sol";
import "test/mocks/MockCommitIntent.sol";
import "test/mocks/MockLabelValidator.sol";
import "test/mocks/MockRegistrationStrategy.sol";
import "test/mocks/MockUsdOracle.sol";
import "test/mocks/MockGlobalRegistrationStrategy.sol";
import "test/mocks/MockCommitIntent.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "interfaces/ICommitIntent.sol";

contract TestHandshakesld is Test {
    error MissingRegistrationStrategy();

    using stdStorage for StdStorage;
    HandshakeTld tld;
    HandshakeSld sld;
    ITldClaimManager claimManager;
    ICommitIntent commitIntent;

    // test
    bytes32 constant TEST_TLD_NAMEHASH = 0x04f740db81dc36c853ab4205bddd785f46e79ccedca351fc6dfcbd8cc9a33dd6;
    // test.test
    bytes32 constant TEST_sld_NAMEHASH = 0x28f4f6752878f66fd9e3626dc2a299ee01cfe269be16e267e71046f1022271cb;
    // test.test.test
    bytes32 constant TEST_SUB_NAMEHASH = 0xab4320f3c1dd20a2fc23e7b0dda6f37afbf916136c4797a99caad59e740d9494;

    function setUp() public {

        commitIntent = new MockCommitIntent(true);
        claimManager = new MockClaimManager();
        tld = new HandshakeTld(claimManager);
        sld = new HandshakeSld(tld, commitIntent);
        addMockValidatorToSld();
        addMockOracle();
    }

    function getNamehash(bytes32 _parentHash, string memory _label) public pure returns (bytes32) {
        return Namehash.getNamehash( _parentHash, _label);
    }

    function getTldNamehash(string memory _label) public pure returns (bytes32) {
        return Namehash.getTldNamehash(_label);
    }

    function testEthTldTokenIds() public {
        // .eth
        // tld labelhash: 0x4f5b812789fc606be1b3b16908db13fc7a9adf7ca72641f84d75b47069d3d7f0
        // tld labelhash int: 35894389512221139346028120028875095598761990588366713962827482865185691260912
        // tld namehash: 0x93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae
        // tld namehash int: 6685381733461190219423816448488981918031594240242612856324574583496001347703

        // aox.eth
        // sld labelhash: 0x76afc3e13980f4710646e2f1af38cfa1e0e584a1d61d3c6057b23efe6a19c05b
        // sld labelhash int: 53683466281743124927853074219771454931349794037600093387976968725467848360027
        // sld namehash: 0x81f536edca1dbdb9582598140d28a86010c4dbb395f128647f1add370d334d89
        // sld namehash int: 58781614103207472765857548334332670569870930160421619975555094596235683909001

        // test aox.eth
        string memory sldLabel = "aox";
        string memory tldLabel = "eth";

        // bytes32 tldLabelhash = keccak256(abi.encodePacked(tldLabel));
        bytes32 tldNamehash = getNamehash(bytes32(0), tldLabel);

        // emit log_named_string("tld", tldLabel);
        // emit log_named_bytes32("tld labelhash", tldLabelhash);
        // emit log_named_bytes32("tld namehash", tldNamehash);
        // emit log_named_uint("tld namehash int", uint256(tldNamehash));

        // bytes32 sldLabelhash = keccak256(abi.encodePacked(sldLabel));
        bytes32 sldNamehash = getNamehash(tldNamehash, sldLabel);

        // emit log_named_string("sld", sldLabel);
        // emit log_named_bytes32("sld labelhash", sldLabelhash);
        // emit log_named_uint("sld labelhash int", uint256(sldLabelhash));

        // emit log_named_bytes32("sld namehash", sldNamehash);
        // emit log_named_uint("sld namehash int", uint256(sldNamehash));

        addMockCommitIntent(true);
        address parent_address = address(0x12345678);
        address child_address = address(0x22446688);

        vm.startPrank(parent_address);

        stdstore.target(address(sld.handshakeTldContract())).sig("claimManager()").checked_write(
            parent_address
        );
        sld.handshakeTldContract().mint(parent_address, tldLabel);

        address strat = address(new MockRegistrationStrategy(0));
        sld.setPricingStrategy(uint256(tldNamehash), strat);
        assertEq(address(sld.getPricingStrategy(tldNamehash)), strat);

        // check .eth tld token ID
        assertEq(tldNamehash, 0x93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae);
        vm.stopPrank();

        vm.startPrank(child_address);

        bytes32[] memory emptyArr;

        sld.purchaseSingleDomain(
            sldLabel,
            bytes32(uint256(0x0)),
            666,
            tldNamehash,
            emptyArr,
            child_address
        );

        // check aox.eth sld token ID
        assertEq(sldNamehash, 0x81f536edca1dbdb9582598140d28a86010c4dbb395f128647f1add370d334d89);

    }

    function testTestTldTokenIds() public {

        // .test
        // tld labelhash: 0x9c22ff5f21f0b81b113e63f7db6da94fedef11b2119b4088b89664fb9a3cb658
        // tld namehash: 0x04f740db81dc36c853ab4205bddd785f46e79ccedca351fc6dfcbd8cc9a33dd6
        // tld namehash int: 2246110249003717592995719785342735456823593955286278257408408162934437658070

        // test.test
        // sld labelhash: 0x9c22ff5f21f0b81b113e63f7db6da94fedef11b2119b4088b89664fb9a3cb658
        // sld labelhash int: 70622639689279718371527342103894932928233838121221666359043189029713682937432
        // sld namehash: 0x28f4f6752878f66fd9e3626dc2a299ee01cfe269be16e267e71046f1022271cb
        // sld namehash int: 18525325615313904658989563537422688421354628918912926368091081131812458754507

        // test.test.test
        // sub namehash: 0xab4320f3c1dd20a2fc23e7b0dda6f37afbf916136c4797a99caad59e740d9494
        // sub namehash int: 77464103288645080441481072468819809447960920101373085550134511165123855226004

        // test test.test
        string memory sldLabel = "test";
        string memory tldLabel = "test";

        bytes32 tldNamehash = getNamehash(bytes32(0), tldLabel);
        bytes32 sldNamehash = getNamehash(tldNamehash, sldLabel);
        bytes32 subNamehash = getNamehash(sldNamehash, sldLabel);

        // emit log_named_bytes32("sld namehash", sldNamehash);
        // emit log_named_uint("sld namehash int", uint256(sldNamehash));

        // emit log_named_bytes32("sub namehash", subNamehash);
        // emit log_named_uint("sub namehash int", uint256(subNamehash));

        addMockCommitIntent(true);
        address parent_address = address(0x12345678);
        address child_address = address(0x22446688);

        vm.startPrank(parent_address);

        stdstore.target(address(sld.handshakeTldContract())).sig("claimManager()").checked_write(
            parent_address
        );
        sld.handshakeTldContract().mint(parent_address, tldLabel);

        address strat = address(new MockRegistrationStrategy(0));
        sld.setPricingStrategy(uint256(tldNamehash), strat);
        assertEq(address(sld.getPricingStrategy(tldNamehash)), strat);

        // check .test tld token ID
        assertEq(tldNamehash, 0x04f740db81dc36c853ab4205bddd785f46e79ccedca351fc6dfcbd8cc9a33dd6);
        vm.stopPrank();

        vm.startPrank(child_address);

        bytes32[] memory emptyArr;

        sld.purchaseSingleDomain(
            sldLabel,
            bytes32(uint256(0x0)),
            666,
            tldNamehash,
            emptyArr,
            child_address
        );

        // check test.test sld token ID
        assertEq(sldNamehash, 0x28f4f6752878f66fd9e3626dc2a299ee01cfe269be16e267e71046f1022271cb);

        vm.stopPrank();
    }

    function mintSingleSubdomain(
        string memory _label,
        bytes32 _secret,
        uint256 _registrationLength,
        bytes32 _parentNamehash,
        address _receiver,
        uint256 _wei
    ) private {
        string[] memory label = new string[](1);
        bytes32[] memory secret = new bytes32[](1);
        uint256[] memory registrationLength = new uint256[](1);
        bytes32[] memory parentNamehash = new bytes32[](1);
        bytes32[][] memory proofs = new bytes32[][](1);
        address[] memory receiver = new address[](1);

        label[0] = _label;
        secret[0] = _secret;
        registrationLength[0] = _registrationLength;
        parentNamehash[0] = _parentNamehash;

        receiver[0] = _receiver;

        sld.purchaseMultipleSld{value: _wei}(
            label,
            secret,
            registrationLength,
            parentNamehash,
            receiver
        );
    }

    function addMockValidatorToSld() private {
        //this mock validator will always pass true
        MockLabelValidator validator = new MockLabelValidator(true);

        //update commit intent with mock object
        stdstore.target(address(sld)).sig("validator()").checked_write(address(validator));
    }

    function _addMockRegistrationStrategyToTld(MockRegistrationStrategy _strategy, bytes32 _tldNamehash, uint256 _price) private {
        stdstore
            .target(address(sld))
            .sig("sldDefaultRegistrationStrategy(bytes32)")
            .with_key(_tldNamehash)
            .checked_write(address(_strategy));
    }

    function addMockRegistrationStrategyToTldWithPrice(bytes32 _tldNamehash, uint256 _price) private {
        MockRegistrationStrategy strategy = new MockRegistrationStrategy(_price);
        _addMockRegistrationStrategyToTld(strategy, _tldNamehash, _price);

    }

    function addMockRegistrationStrategyToTld(bytes32 _tldNamehash) private {
        MockRegistrationStrategy strategy = new MockRegistrationStrategy(0);
        _addMockRegistrationStrategyToTld(strategy, _tldNamehash, 0);
    }

    function addMockOracle() private {
        MockUsdOracle oracle = new MockUsdOracle(200000000000);
        stdstore.target(address(sld)).sig("usdOracle()").checked_write(address(oracle));
    }

    function addMockCommitIntent(bool _returnValue) private {
        MockCommitIntent intent = new MockCommitIntent(_returnValue);

        //update commit intent with mock object
        stdstore.target(address(sld)).sig("commitIntent()").checked_write(address(intent));
    }

    function testUpdateLabelValidatorWithOwnerWalletExpectSuccess() public {
        MockLabelValidator validator = new MockLabelValidator(false);
        sld.updateLabelValidator(validator);
        assertEq(address(sld.validator()), address(validator));
    }

    function testUpdateLabelValidatorWithNotOwnerWalletExpectFail() public {
        //assign
        MockLabelValidator validator = new MockLabelValidator(false);
        address currentValidatorAddress = address(sld.validator());
        address otherWallet = address(0x224466);

        //act
        vm.startPrank(otherWallet);
        vm.expectRevert("Ownable: caller is not the owner");
        sld.updateLabelValidator(validator);

        //assert
        //should not have changed
        assertEq(currentValidatorAddress, address(sld.validator()));
        vm.stopPrank();
    }

    function testOwnerOfTldContractSetCorrectly() public {
        assertEq(address(this), Ownable(address(sld.handshakeTldContract())).owner());
    }


    function testMintsldFromAuthorisedWallet() public {
        string memory label = "";
        bytes32 secret = bytes32(0x0);
        uint256 registrationLength = 365;
        bytes32 parentNamehash = getTldNamehash("testtest");

        addMockRegistrationStrategyToTld(parentNamehash);
        addMockCommitIntent(true);

        address tldOwner = address(0x12345dddd679);

        HandshakeTld tld = sld.handshakeTldContract();
        sld.setHandshakeWalletAddress(address(0x646464));
        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.startPrank(tldOwner);
        tld.mint(tldOwner, "testtest");

        vm.stopPrank();

        bytes32[] memory empty_array;
        address claimant = address(0x6666);

        vm.startPrank(claimant);
        sld.purchaseSingleDomain(
            label,
            secret,
            registrationLength,
            parentNamehash,
            empty_array,
            claimant
        );
        vm.stopPrank();

        assertEq(sld.balanceOf(claimant), 1);
    }

    function testMintsldFromAuthorisedWalletRepurchaseWhenExpired() public {
        string memory label = "";
        bytes32 secret = bytes32(0x0);
        uint256 registrationLength = 365;
        bytes32 parentNamehash = getTldNamehash("packed");

        addMockRegistrationStrategyToTld(parentNamehash);
        addMockCommitIntent(true);

        bytes32[] memory empty_array;
        address claimant = address(0x6666);

        address tldOwner = address(0x12345dddd679);

        HandshakeTld tld = sld.handshakeTldContract();
        sld.setHandshakeWalletAddress(address(0x646464));
        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.startPrank(tldOwner);
        tld.mint(tldOwner, "packed");

        vm.stopPrank();

        vm.startPrank(claimant);
        sld.purchaseSingleDomain(
            label,
            secret,
            registrationLength,
            parentNamehash,
            empty_array,
            claimant
        );
        vm.warp(block.timestamp + 0 + (86400 * registrationLength));
        vm.expectRevert("Subdomain already registered");
        sld.purchaseSingleDomain(
            label,
            secret,
            registrationLength,
            parentNamehash,
            empty_array,
            claimant
        );

        vm.warp(block.timestamp + 1);
        sld.purchaseSingleDomain(
            label,
            secret,
            registrationLength,
            parentNamehash,
            empty_array,
            claimant
        );
        vm.stopPrank();

        assertEq(sld.balanceOf(claimant), 1);
    }

    function testMintsldFromAuthorisedWalletWithMissingRegistrationStrategy() public {
        string memory label = "";
        bytes32 secret = bytes32(0x0);
        uint256 registrationLength = 365;
        bytes32 parentNamehash = bytes32(0x0);

        //comment out for the test.
        //addMockRegistrationStrategyToTld(parentNamehash);
        addMockCommitIntent(true);

        bytes32[] memory empty_array;
        address claimant = address(0x6666);

        vm.startPrank(claimant);
        vm.expectRevert(MissingRegistrationStrategy.selector);
        sld.purchaseSingleDomain(
            label,
            secret,
            registrationLength,
            parentNamehash,
            empty_array,
            claimant
        );
        vm.stopPrank();

        assertEq(sld.balanceOf(claimant), 0);
    }

    function testMintDuplicatesldFromAuthorisedWallet() public {
        string memory label = "";
        bytes32 secret = bytes32(0x0);
        uint256 registrationLength = 365;
        bytes32 parentNamehash = getTldNamehash("yyyyy");

        addMockRegistrationStrategyToTld(parentNamehash);
        addMockCommitIntent(true);

        address tldOwner = address(0x12345679);

        HandshakeTld tld = sld.handshakeTldContract();

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.startPrank(tldOwner);
        tld.mint(tldOwner, "yyyyy");

        vm.stopPrank();

        address claimant = address(0x6666);
        bytes32[] memory empty_array;
        vm.startPrank(claimant);
        sld.purchaseSingleDomain(
            label,
            secret,
            registrationLength,
            parentNamehash,
            empty_array,
            claimant
        );
        vm.expectRevert("Subdomain already registered");
        sld.purchaseSingleDomain(
            label,
            secret,
            registrationLength,
            parentNamehash,
            empty_array,
            claimant
        );
        vm.stopPrank();

        assertEq(sld.balanceOf(claimant), 1);
    }

    function testCheckParentNamehashIsCorrectAfterMint() public {
        string memory label = "testing";
        bytes32 secret = bytes32(0x0);
        uint256 registrationLength = 365;
        bytes32 parentNamehash = getTldNamehash("testing");

        addMockRegistrationStrategyToTld(parentNamehash);
        addMockCommitIntent(true);

        address tldOwner = address(0x12345679);

        HandshakeTld tld = sld.handshakeTldContract();

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.startPrank(tldOwner);
        tld.mint(tldOwner, "testing");

        vm.stopPrank();

        address claimant = address(0x6666);

        bytes32[] memory empty_array;
        vm.startPrank(claimant);
        sld.purchaseSingleDomain(
            label,
            secret,
            registrationLength,
            parentNamehash,
            empty_array,
            msg.sender
        );

        bytes32 full_hash = getNamehash(parentNamehash, label);

        assertEq(parentNamehash, sld.namehashToParentMap(full_hash));
    }

    function testCheckLabelToNamehashIsCorrectAfterMint() public {
        string memory label = "testing";
        bytes32 secret = bytes32(0x0);
        uint256 registrationLength = 365;
        bytes32 parentNamehash = getTldNamehash("testing");

        addMockRegistrationStrategyToTld(parentNamehash);
        addMockCommitIntent(true);

        address tldOwner = address(0x12345679);

        HandshakeTld tld = sld.handshakeTldContract();

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.startPrank(tldOwner);
        tld.mint(tldOwner, "testing");

        vm.stopPrank();

        bytes32[] memory empty_array;
        address claimant = address(0x6666);

        vm.startPrank(claimant);
        sld.purchaseSingleDomain(
            label,
            secret,
            registrationLength,
            parentNamehash,
            empty_array,
            msg.sender
        );

        bytes32 full_hash = getNamehash(parentNamehash, label);

        assertEq(label, sld.namehashToLabelMap(full_hash));
    }

    function testMultiPurchasesldWithIncorrectArrayLengths_expectFail() public {
        string[] memory label = new string[](3);
        bytes32[] memory secret = new bytes32[](3);
        uint256[] memory registrationLength = new uint256[](3);
        bytes32[] memory parentNamehash = new bytes32[](3);
        bytes32[][] memory proofs = new bytes32[][](3);
        address[] memory receiver = new address[](2);

        vm.expectRevert("all arrays should be the same length");
        sld.purchaseMultipleSld(label, secret, registrationLength, parentNamehash, receiver);
    }

    function testMultiPurchasesldWithIncorrectArrayLengths_expectFail_2() public {
        string[] memory label = new string[](2);
        bytes32[] memory secret = new bytes32[](3);
        uint256[] memory registrationLength = new uint256[](3);
        bytes32[] memory parentNamehash = new bytes32[](3);
        bytes32[][] memory proofs = new bytes32[][](3);
        address[] memory receiver = new address[](3);

        vm.expectRevert("all arrays should be the same length");
        sld.purchaseMultipleSld(label, secret, registrationLength, parentNamehash, receiver);
    }

    function testMultiPurchasesld() public {
        string[] memory label = new string[](2);
        bytes32[] memory secret = new bytes32[](2);
        uint256[] memory registrationLength = new uint256[](2);
        bytes32[] memory parentNamehash = new bytes32[](2);

        label[0] = "test1";
        label[1] = "test2";

        secret[0] = bytes32(abi.encodePacked(uint256(0x0)));
        secret[1] = bytes32(abi.encodePacked(uint256(0x1)));

        registrationLength[0] = 365;
        registrationLength[1] = 365;

        parentNamehash[0] = getTldNamehash("yo");
        parentNamehash[1] = getTldNamehash("yoyo");

        addMockRegistrationStrategyToTld(parentNamehash[0]);
        addMockRegistrationStrategyToTld(parentNamehash[1]);

        address tldOwner = address(0x12345679);

        HandshakeTld tld = sld.handshakeTldContract();

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.startPrank(tldOwner);
        tld.mint(tldOwner, "yo");
        tld.mint(tldOwner, "yoyo");
        vm.stopPrank();

        addMockCommitIntent(true);
        sld.setGlobalRegistrationStrategy(address(new MockGlobalRegistrationStrategy(true)));
        address claimant = address(0x6666);
        address[] memory receiver = new address[](2);

        receiver[0] = address(0x0123);
        receiver[1] = address(0x2345);

        vm.startPrank(claimant);
        sld.purchaseMultipleSld(label, secret, registrationLength, parentNamehash, receiver);
        vm.stopPrank();

        assertEq(sld.balanceOf(receiver[0]), 1);
        assertEq(sld.balanceOf(receiver[1]), 1);
        assertEq(sld.balanceOf(claimant), 0);
    }

    function testMultiPurchasesldWithZeroAddressInReceiver() public {
        string[] memory label = new string[](2);
        bytes32[] memory secret = new bytes32[](2);
        uint256[] memory registrationLength = new uint256[](2);
        bytes32[] memory parentNamehash = new bytes32[](2);

        label[0] = "test1";
        label[1] = "test2";

        secret[0] = bytes32(abi.encodePacked(uint256(0x2)));
        secret[1] = bytes32(abi.encodePacked(uint256(0x3)));

        registrationLength[0] = 365;
        registrationLength[1] = 365;

        parentNamehash[0] = getTldNamehash("yes");
        parentNamehash[1] = getTldNamehash("no");

        addMockRegistrationStrategyToTld(parentNamehash[0]);
        addMockRegistrationStrategyToTld(parentNamehash[1]);
        addMockCommitIntent(true);
        sld.setGlobalRegistrationStrategy(address(new MockGlobalRegistrationStrategy(true)));

        address tldOwner = address(0x12345679);
        HandshakeTld tld = sld.handshakeTldContract();

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.startPrank(tldOwner);
        tld.mint(tldOwner, "yes");
        tld.mint(tldOwner, "no");
        vm.stopPrank();

        bytes32[][] memory empty_array = new bytes32[][](2);

        address claimant = address(0x6666);
        address[] memory receiver = new address[](2);

        receiver[0] = address(0x0123);

        //comment this guy out for the test
        //receiver[1] = address(0x2345);

        vm.startPrank(claimant);
        sld.purchaseMultipleSld(label, secret, registrationLength, parentNamehash, receiver);
        vm.stopPrank();

        assertEq(sld.balanceOf(receiver[0]), 1);
        assertEq(sld.balanceOf(claimant), 1);
    }

    function testPurchasesldToZeroAddress_expectSendToMsgSender() public {
        string memory label = "testit";
        bytes32 secret = bytes32(0x0);
        uint256 registrationLength = 365;
        bytes32 parentNamehash = getTldNamehash("heyman");

        addMockRegistrationStrategyToTld(parentNamehash);
        addMockCommitIntent(true);

        bytes32[] memory empty_array;
        address claimant = address(0x6666);

        address tldOwner = address(0x12345679);
        HandshakeTld tld = sld.handshakeTldContract();

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.startPrank(tldOwner);
        tld.mint(tldOwner, "heyman");

        vm.stopPrank();

        vm.startPrank(claimant);

        sld.purchaseSingleDomain(
            label,
            secret,
            registrationLength,
            parentNamehash,
            empty_array,
            address(0)
        );
        vm.stopPrank();

        assertEq(sld.balanceOf(claimant), 1);
    }

    function testPurchasesldToOtherAddress() public {
        string memory label = "testit";
        bytes32 secret = bytes32(0x0);
        uint256 registrationLength = 365;
        bytes32 parentNamehash = getTldNamehash("hash");

        addMockRegistrationStrategyToTld(parentNamehash);
        addMockCommitIntent(true);

        address tldOwner = address(0x12345679);
        HandshakeTld tld = sld.handshakeTldContract();

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.startPrank(tldOwner);
        tld.mint(tldOwner, "hash");
        vm.stopPrank();

        bytes32[] memory empty_array;
        address claimant = address(0x6666);
        address receiver = address(0x8888);

        vm.startPrank(claimant);
        sld.purchaseSingleDomain(
            label,
            secret,
            registrationLength,
            parentNamehash,
            empty_array,
            receiver
        );
        vm.stopPrank();

        assertEq(sld.balanceOf(receiver), 1);
        assertEq(sld.balanceOf(claimant), 0);
    }

    function testMultiPurchasesldToOtherAddressWithMissingRegistrationStrategy_expectFail() public {
        string[] memory label = new string[](2);
        bytes32[] memory secret = new bytes32[](2);
        uint256[] memory registrationLength = new uint256[](2);
        bytes32[] memory parentNamehash = new bytes32[](2);

        label[0] = "test1";
        label[1] = "test2";

        secret[0] = bytes32(abi.encodePacked(uint256(0x0)));
        secret[1] = bytes32(abi.encodePacked(uint256(0x1)));

        registrationLength[0] = 365;
        registrationLength[1] = 365;

        parentNamehash[0] = getTldNamehash("hey");
        parentNamehash[1] = getTldNamehash("you");

        addMockRegistrationStrategyToTld(parentNamehash[0]);
        sld.setGlobalRegistrationStrategy(address(new MockGlobalRegistrationStrategy(true)));
        //commented this out for the test
        //addMockRegistrationStrategyToTld(parentNamehash[1]);
        addMockCommitIntent(true);

        address tldOwner = address(0x12345679);
        HandshakeTld tld = sld.handshakeTldContract();

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.startPrank(tldOwner);
        tld.mint(tldOwner, "hey");
        tld.mint(tldOwner, "you");
        vm.stopPrank();

        bytes32[][] memory empty_array = new bytes32[][](2);

        address claimant = address(0x6666);
        address[] memory receiver = new address[](2);

        receiver[0] = address(0x0123);
        receiver[1] = address(0x2345);

        vm.startPrank(claimant);
        vm.expectRevert(MissingRegistrationStrategy.selector);
        sld.purchaseMultipleSld(label, secret, registrationLength, parentNamehash, receiver);
        vm.stopPrank();
    }

    function testSetRoyaltyPaymentAddressForTldFromTldOwnerAddress() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address payoutAddress = address(0x22886644);

        HandshakeTld tld = sld.handshakeTldContract();

        bytes32[] memory emptyArr;

        bytes32 parent_hash = getTldNamehash(tldName);

        addMockRegistrationStrategyToTld(parent_hash);
        addMockCommitIntent(true);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.mint(tldOwner, tldName);

        vm.prank(sldOwner);
        sld.purchaseSingleDomain("test", bytes32(0x0), 365, parent_hash, emptyArr, sldOwner);

        // test.test
        uint256 expectedsldId = uint256(getNamehash(parent_hash, "test"));

        assertEq(
            expectedsldId,
            uint256(TEST_sld_NAMEHASH)
        );

        uint256 tldId = uint256(parent_hash);
        assertEq(tldId, uint256(TEST_TLD_NAMEHASH));
        console.log('yoyoyoyo');
        vm.prank(tldOwner);
        sld.setRoyaltyPayoutAddress(tldId, payoutAddress);
        (address _addr, ) = sld.royaltyInfo(expectedsldId, 100);
        assertEq(_addr, payoutAddress);
        vm.stopPrank();
    }

    function testSetRoyaltyPaymentAddressForTldNotSet_ShouldReturnTldOwner() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address payoutAddress = address(0x22886644);

        HandshakeTld tld = sld.handshakeTldContract();

        bytes32[] memory emptyArr;

        bytes32 parent_hash = getTldNamehash(tldName);

        addMockRegistrationStrategyToTld(parent_hash);
        addMockCommitIntent(true);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.mint(tldOwner, tldName);

        vm.prank(sldOwner);
        sld.purchaseSingleDomain("test", bytes32(0x0), 365, parent_hash, emptyArr, sldOwner);

        // test.test
        uint256 expectedsldId = uint256(getNamehash( parent_hash, "test"));

        assertEq(
            expectedsldId,
            uint256(TEST_sld_NAMEHASH)
        );

        uint256 tldId = uint256(getTldNamehash(tldName));

        assertEq(tldId, uint256(parent_hash));

        (address _addr, ) = sld.royaltyInfo(expectedsldId, 100);
        assertEq(_addr, tldOwner);
        vm.stopPrank();
    }

    function testSetRoyaltyPaymentAddressThenTransferTld_AddressShouldResetToNewOwner() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address payoutAddress = address(0x22886644);

        HandshakeTld tld = sld.handshakeTldContract();

        bytes32[] memory emptyArr;

        bytes32 parent_hash = getTldNamehash(tldName);

        addMockRegistrationStrategyToTld(parent_hash);
        addMockCommitIntent(true);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.mint(tldOwner, tldName);

        vm.prank(sldOwner);
        sld.purchaseSingleDomain("test", bytes32(0x0), 365, parent_hash, emptyArr, sldOwner);

        // test.test
        uint256 expectedsldId = uint256(getNamehash(parent_hash, "test"));

        assertEq(
            expectedsldId,
            uint256(TEST_sld_NAMEHASH)
        );

        uint256 tldId = uint256(getTldNamehash(tldName));

        assertEq(tldId, uint256(parent_hash));

        vm.startPrank(tldOwner);
        sld.setRoyaltyPayoutAddress(tldId, payoutAddress);
        (address _addr, ) = sld.royaltyInfo(expectedsldId, 100);
        assertEq(_addr, payoutAddress);

        address newOwner = address(0x66);

        sld.handshakeTldContract().safeTransferFrom(tldOwner, newOwner, tldId);
        (address _addr2, ) = sld.royaltyInfo(expectedsldId, 100);
        assertEq(_addr2, newOwner);

        vm.stopPrank();
    }

    function testSetRoyaltyPaymentAddressForTldFromTldOwnerApprovedAddress() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address payoutAddress = address(0x22886644);

        HandshakeTld tld = sld.handshakeTldContract();

        bytes32[] memory emptyArr;

        bytes32 parent_hash = getTldNamehash(tldName);

        addMockRegistrationStrategyToTld(parent_hash);
        addMockCommitIntent(true);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.mint(tldOwner, tldName);

        vm.prank(sldOwner);
        sld.purchaseSingleDomain("test", bytes32(0x0), 365, parent_hash, emptyArr, sldOwner);

        // test.test
        uint256 expectedsldId = uint256(getNamehash(parent_hash, "test"));

        assertEq(
            expectedsldId,
            uint256(TEST_sld_NAMEHASH)
        );

        uint256 tldId = uint256(getTldNamehash(tldName));

        assertEq(tldId, uint256(parent_hash));

        address approvedAddress = address(0x2299);

        vm.startPrank(tldOwner); //need to start/stop prank as this is a chained call
        sld.handshakeTldContract().setApprovalForAll(approvedAddress, true);
        vm.stopPrank();

        vm.prank(approvedAddress);
        sld.setRoyaltyPayoutAddress(tldId, payoutAddress);
        (address _addr, ) = sld.royaltyInfo(expectedsldId, 100);
        assertEq(_addr, payoutAddress);
        vm.stopPrank();
    }

    function testSetRoyaltyPaymentAddressForTldFromNotTldOwnerAddress_ExpectFail() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address payoutAddress = address(0x22886644);

        HandshakeTld tld = sld.handshakeTldContract();

        bytes32[] memory emptyArr;

        bytes32 parent_hash = getTldNamehash(tldName);

        addMockRegistrationStrategyToTld(parent_hash);
        addMockCommitIntent(true);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.mint(tldOwner, tldName);

        vm.prank(sldOwner);
        sld.purchaseSingleDomain("test", bytes32(0x0), 365, parent_hash, emptyArr, sldOwner);

        // test.test
        uint256 expectedsldId = uint256(getNamehash(parent_hash, "test"));

        assertEq(
            expectedsldId,
            uint256(TEST_sld_NAMEHASH)
        );

        uint256 tldId = uint256(getTldNamehash(tldName));

        assertEq(tldId, uint256(parent_hash));

        address notApprovedAddress = address(0x2299);

        vm.prank(notApprovedAddress);
        vm.expectRevert("ERC721: invalid token ID");
        sld.setRoyaltyPayoutAddress(tldId, payoutAddress);
    }

    function testSetRoyaltyPaymentAmountForTldFromTldOwnerAddress() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address payoutAddress = address(0x22886644);

        HandshakeTld tld = sld.handshakeTldContract();

        bytes32[] memory emptyArr;

        bytes32 parent_hash = getTldNamehash(tldName);

        addMockRegistrationStrategyToTld(parent_hash);
        addMockCommitIntent(true);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.mint(tldOwner, tldName);

        vm.prank(sldOwner);
        sld.purchaseSingleDomain("test", bytes32(0x0), 365, parent_hash, emptyArr, sldOwner);

        // test.test
        uint256 expectedsldId = uint256(getNamehash(parent_hash, "test"));

        assertEq(
            expectedsldId,
            uint256(TEST_sld_NAMEHASH)
        );

        uint256 tldId = uint256(getTldNamehash(tldName));

        assertEq(tldId, uint256(parent_hash));

        uint256 expectedRoyaltyAmount = 90;
        uint256 setRoyaltyNumber = 3;

        vm.prank(tldOwner);
        sld.setRoyaltyPayoutAmount(tldId, setRoyaltyNumber);
        (, uint256 royaltyAmount) = sld.royaltyInfo(expectedsldId, 3000);
        assertEq(royaltyAmount, expectedRoyaltyAmount);
        vm.stopPrank();
    }

    function testSetRoyaltyPaymentAmountForTldFromTldOwnerAddressOver10Percent_expectFail() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address payoutAddress = address(0x22886644);

        HandshakeTld tld = sld.handshakeTldContract();

        bytes32[] memory emptyArr;

        bytes32 parent_hash = getTldNamehash(tldName);

        addMockRegistrationStrategyToTld(parent_hash);
        addMockCommitIntent(true);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.mint(tldOwner, tldName);

        vm.prank(sldOwner);
        sld.purchaseSingleDomain("test", bytes32(0x0), 365, parent_hash, emptyArr, sldOwner);

        // test.test
        uint256 expectedsldId = uint256(getNamehash(parent_hash, "test"));

        uint256 tldId = uint256(getTldNamehash(tldName));

        uint256 setRoyaltyNumber = 11;

        vm.startPrank(tldOwner);

        //not expecting fail from this one
        sld.setRoyaltyPayoutAmount(tldId, 10);

        vm.expectRevert("10% maximum royalty on SLD");
        sld.setRoyaltyPayoutAmount(tldId, setRoyaltyNumber);
    }

    function testRoyaltyPaymentAmountNotSetForTldFromTldOwnerAddress() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address payoutAddress = address(0x22886644);

        HandshakeTld tld = sld.handshakeTldContract();

        bytes32[] memory emptyArr;

        bytes32 parent_hash = getTldNamehash(tldName);

        addMockRegistrationStrategyToTld(parent_hash);
        addMockCommitIntent(true);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.mint(tldOwner, tldName);

        vm.prank(sldOwner);
        sld.purchaseSingleDomain("test", bytes32(0x0), 365, parent_hash, emptyArr, sldOwner);

        // test.test
        uint256 expectedsldId = uint256(getNamehash(parent_hash, "test"));

        assertEq(
            expectedsldId,
            uint256(TEST_sld_NAMEHASH)
        );

        uint256 tldId = uint256(getTldNamehash(tldName));

        assertEq(tldId, uint256(parent_hash));

        uint256 expectedRoyaltyAmount = 0;

        (, uint256 royaltyAmount) = sld.royaltyInfo(expectedsldId, 100);
        assertEq(royaltyAmount, expectedRoyaltyAmount);
        vm.stopPrank();
    }

    function testSetRoyaltyPaymentAmountForTldFromTldOwnerApprovedAddress() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address payoutAddress = address(0x22886644);

        HandshakeTld tld = sld.handshakeTldContract();

        bytes32[] memory emptyArr;

        bytes32 parent_hash = getTldNamehash(tldName);

        addMockRegistrationStrategyToTld(parent_hash);
        addMockCommitIntent(true);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.mint(tldOwner, tldName);

        vm.prank(sldOwner);
        sld.purchaseSingleDomain("test", bytes32(0x0), 365, parent_hash, emptyArr, sldOwner);

        // test.test
        uint256 expectedsldId = uint256(getNamehash(parent_hash, "test"));

        assertEq(
            expectedsldId,
            uint256(TEST_sld_NAMEHASH)
        );

        uint256 tldId = uint256(getTldNamehash(tldName));

        assertEq(tldId, uint256(parent_hash));

        address approvedAddress = address(0x2299);

        vm.startPrank(tldOwner); //need to start/stop prank as this is a chained call
        sld.handshakeTldContract().setApprovalForAll(approvedAddress, true);
        vm.stopPrank();

        uint256 expectedRoyaltyAmount = 1;
        uint256 setRoyaltyNumber = 1;

        vm.prank(approvedAddress);
        sld.setRoyaltyPayoutAmount(tldId, setRoyaltyNumber);
        emit log_named_uint("royalty amount set", sld.royaltyPayoutAmountMap(parent_hash));
        (, uint256 royaltyAmount) = sld.royaltyInfo(expectedsldId, 100);
        assertEq(royaltyAmount, expectedRoyaltyAmount);
    }

    function testAddRegistrationStrategyToTldDomain_pass() public {
        bytes32 parentNamehash = TEST_TLD_NAMEHASH;
        addMockCommitIntent(true);

        string memory domain = "test";
        address parent_address = address(0x12345678);
        stdstore.target(address(sld.handshakeTldContract())).sig("claimManager()").checked_write(
            parent_address
        );

        vm.startPrank(parent_address);
        sld.handshakeTldContract().mint(parent_address, domain);

        address strat = address(new MockRegistrationStrategy(1));
        sld.setPricingStrategy(uint256(parentNamehash), strat);

        assertEq(address(sld.getPricingStrategy(parentNamehash)), strat);
    }

    function ignoreAddRegistrationStrategyTosldDomain_pass() public {
        bytes32 parentNamehash = TEST_TLD_NAMEHASH;
        addMockCommitIntent(true);

        string memory domain = "test";
        address parent_address = address(0x12345678);
        address child_address = address(0x22446688);
        stdstore.target(address(sld.handshakeTldContract())).sig("claimManager()").checked_write(
            parent_address
        );

        vm.startPrank(parent_address);
        tld.mint(parent_address, domain);

        address strat = address(new MockRegistrationStrategy(0));
        sld.setPricingStrategy(uint256(parentNamehash), strat);

        emit log_named_address("usd address", address(sld.usdOracle()));
        emit log_named_uint("usd value", sld.usdOracle().getPrice());

        assertEq(address(sld.getPricingStrategy(parentNamehash)), strat);
        vm.stopPrank();

        vm.startPrank(child_address);
        bytes32[] memory emptyArr;

        bytes32 namehash = getNamehash(parentNamehash, "test");
        console.log('expected namehash');
        console.log(uint256(namehash));
        sld.purchaseSingleDomain(
            "test",
            bytes32(parentNamehash),
            666,
            parentNamehash,
            emptyArr,
            child_address
        );

        console.log("yoyoyoyo");
        address childStrat = address(new MockRegistrationStrategy(1));
        sld.setPricingStrategy(uint256(namehash), childStrat);

        assertEq(address(sld.getPricingStrategy(namehash)), childStrat);
        vm.stopPrank();
    }

    function ignoretestAddRegistrationStrategyTosldNotOwner_fail() public {
        bytes32 parentNamehash = TEST_TLD_NAMEHASH;
        addMockCommitIntent(true);

        string memory domain = "test";
        address parent_address = address(0x12345678);
        address child_address = address(0x22446688);
        stdstore.target(address(sld.handshakeTldContract())).sig("claimManager()").checked_write(
            parent_address
        );

        vm.startPrank(parent_address);
        sld.handshakeTldContract().mint(parent_address, domain);

        address strat = address(new MockRegistrationStrategy(0));
        sld.setPricingStrategy(uint256(parentNamehash), strat);

        assertEq(address(sld.getPricingStrategy(parentNamehash)), strat);
        vm.stopPrank();

        vm.startPrank(child_address);

        bytes32[] memory emptyArr;

        bytes32 namehash = getNamehash( parentNamehash, "test");

        //we mint to other address 0x1337
        sld.purchaseSingleDomain(
            "test",
            bytes32(uint256(0x0)),
            666,
            parentNamehash,
            emptyArr,
            address(0x1337)
        );
        address childStrat = address(new MockRegistrationStrategy(1));
        vm.expectRevert("ERC721: invalid token ID");
        sld.setPricingStrategy(uint256(namehash), childStrat);

        vm.stopPrank();
    }

    function testAddRegistrationStrategyToTldNotOwner_fail() public {
        bytes32 parentNamehash = TEST_TLD_NAMEHASH;
        addMockCommitIntent(true);

        string memory domain = "test";
        address parent_address = address(0x12345678);
        address not_parent_address = address(0x222222);
        stdstore.target(address(sld.handshakeTldContract())).sig("claimManager()").checked_write(
            parent_address
        );

        vm.startPrank(parent_address);
        sld.handshakeTldContract().mint(parent_address, domain);
        vm.stopPrank();

        vm.startPrank(not_parent_address);
        address strat = address(new MockRegistrationStrategy(1));
        vm.expectRevert("ERC721: invalid token ID");
        sld.setPricingStrategy(uint256(parentNamehash), strat);
    }

    function testSetRoyaltyPaymentAmountForTldFromNotTldOwnerAddress_ExpectFail() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address payoutAddress = address(0x22886644);

        HandshakeTld tld = sld.handshakeTldContract();

        bytes32[] memory emptyArr;

        bytes32 parent_hash = getTldNamehash(tldName);

        addMockRegistrationStrategyToTld(parent_hash);
        addMockCommitIntent(true);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.mint(tldOwner, tldName);

        vm.prank(sldOwner);
        sld.purchaseSingleDomain("test", bytes32(0x0), 365, parent_hash, emptyArr, sldOwner);

        // test.test
        uint256 expectedsldId = uint256(getNamehash(parent_hash, "test"));

        assertEq(
            expectedsldId,
            uint256(TEST_sld_NAMEHASH)
        );

        uint256 tldId = uint256(getTldNamehash(tldName));

        assertEq(tldId, uint256(parent_hash));

        address notApprovedAddress = address(0x2299);

        uint256 expectedRoyaltyAmount = 1;
        uint256 setRoyaltyNumber = 10;

        vm.prank(notApprovedAddress);
        vm.expectRevert("ERC721: invalid token ID");
        sld.setRoyaltyPayoutAmount(tldId, setRoyaltyNumber);
    }

    function ignoretestSetRoyaltyPaymentAddressForsldChildFromsldOwnerAddress() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address sldsldOwner = address(0xababab);

        HandshakeTld tld = sld.handshakeTldContract();

        bytes32[] memory emptyArr;

        bytes32 parent_hash = getTldNamehash(tldName);

        addMockRegistrationStrategyToTld(parent_hash);
        addMockCommitIntent(true);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.mint(tldOwner, tldName);

        vm.prank(sldOwner);
        sld.purchaseSingleDomain("test", bytes32(0x0), 365, parent_hash, emptyArr, sldOwner);

        bytes32 sldHash = getNamehash(parent_hash, "test");

        uint256 sldId = uint256(sldHash);

        // test.test.test
        uint256 expectedsldChildId = uint256(getNamehash(sldHash, string("test")));

        addMockRegistrationStrategyToTld(sldHash);

        vm.prank(sldsldOwner);
        sld.purchaseSingleDomain("test", bytes32(0x0), 365, sldHash, emptyArr, sldsldOwner);

        assertEq(
            sld.ownerOf(
                uint256(TEST_sld_NAMEHASH)
            ),
            sldsldOwner,
            "no owner of child of sld"
        );

        assertEq(
            expectedsldChildId,
            uint256(TEST_sld_NAMEHASH),
            "id for child of sld does not return correctly."
        );

        uint256 tldId = uint256(getTldNamehash(tldName));

        assertEq(tldId, uint256(parent_hash));

        address notApprovedAddress = address(0x2299);

        uint256 expectedRoyaltyAmount = 4;
        uint256 setRoyaltyNumber = 2;

        vm.prank(sldOwner);
        sld.setRoyaltyPayoutAmount(sldId, setRoyaltyNumber);

        (, uint256 royaltyAmount) = sld.royaltyInfo(expectedsldChildId, 200);
        assertEq(royaltyAmount, expectedRoyaltyAmount);
    }

    function testSetsldRoyaltyPaymentAddressForsldChildFromTldOwnerAddress_expectFail() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address sldsldOwner = address(0xababab);
        address payoutAddress = address(0x22886644);

        HandshakeTld tld = sld.handshakeTldContract();

        bytes32[] memory emptyArr;

        bytes32 parent_hash = getTldNamehash(tldName);

        addMockRegistrationStrategyToTld(parent_hash);
        addMockCommitIntent(true);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.mint(tldOwner, tldName);

        vm.prank(sldOwner);
        sld.purchaseSingleDomain("test", bytes32(0x0), 365, parent_hash, emptyArr, sldOwner);

        bytes32 sldHash = getNamehash(parent_hash, "test");

        uint256 sldId = uint256(sldHash);

        // test.test.test
        uint256 expectedsldChildId = uint256(getNamehash(sldHash, "test"));

        addMockRegistrationStrategyToTld(sldHash);

        vm.prank(sldsldOwner);
        sld.purchaseSingleDomain("test", bytes32(0x0), 365, sldHash, emptyArr, sldsldOwner);

        assertEq(
            sld.ownerOf(
                uint256(TEST_SUB_NAMEHASH)
            ),
            sldsldOwner,
            "no owner of child of sld"
        );

        assertEq(
            expectedsldChildId,
            uint256(TEST_SUB_NAMEHASH),
            "id for child of sld does not return correctly."
        );

        uint256 tldId = uint256(getTldNamehash(tldName));

        assertEq(tldId, uint256(parent_hash));

        uint256 expectedRoyaltyAmount = 1;
        uint256 setRoyaltyNumber = 10;

        vm.prank(tldOwner);
        vm.expectRevert("ERC721: invalid token ID");
        sld.setRoyaltyPayoutAmount(sldId, setRoyaltyNumber);
    }


    function ignoretestSetRoyaltyPaymentAddressForsldChildrenFromsldOwner() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address sldsldOwner = address(0xababab);
        address payoutAddress = address(0x22886644);

        HandshakeTld tld = sld.handshakeTldContract();

        bytes32[] memory emptyArr;

        bytes32 parent_hash = getTldNamehash(tldName);

        addMockRegistrationStrategyToTld(parent_hash);
        addMockCommitIntent(true);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.mint(tldOwner, tldName);

        vm.prank(sldOwner);
        sld.purchaseSingleDomain("test", bytes32(0x0), 365, parent_hash, emptyArr, sldOwner);

        assertEq(
            sld.ownerOf(
                uint256(TEST_sld_NAMEHASH)
            ),
            sldOwner,
            "sld owner not correct"
        );

        bytes32 sldHash = getNamehash(parent_hash, "test");

        uint256 sldId = uint256(sldHash);

        // test.test.test
        uint256 expectedsldChildId = uint256(getNamehash(sldHash, string("test")));

        addMockRegistrationStrategyToTld(sldHash);

        vm.prank(sldsldOwner);
        sld.purchaseSingleDomain("test", bytes32(0x0), 365, sldHash, emptyArr, sldsldOwner);

        assertEq(
            sld.ownerOf(
                uint256(TEST_SUB_NAMEHASH)
            ),
            sldsldOwner,
            "no owner of child of sld"
        );

        assertEq(
            expectedsldChildId,
            uint256(TEST_SUB_NAMEHASH),
            "id for child of sld does not return correctly."
        );

        uint256 tldId = uint256(getTldNamehash(tldName));

        assertEq(tldId, uint256(parent_hash));

        bytes32 parentNamehash = sld.namehashToParentMap(sldHash);
        uint256 parentId = uint256(parentNamehash);

        emit log_named_uint("parent id is :", parentId);
        emit log_named_uint("expected parent id is :", tldId);

        vm.startPrank(sldOwner);
        sld.setRoyaltyPayoutAddress(sldId, payoutAddress);

        (address _addr, ) = sld.royaltyInfo(expectedsldChildId, 100);
        assertEq(_addr, payoutAddress);
        vm.stopPrank();
    }

    //no longer need royalty payments for slds
    function ignoretestSetRoyaltyPaymentAddressThenTransfersldParentNft_AddressShouldResetToNewOwner()
        public
    {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address sldsldOwner = address(0xababab);
        address payoutAddress = address(0x22886644);

        HandshakeTld tld = sld.handshakeTldContract();

        bytes32[] memory emptyArr;

        bytes32 parent_hash = getTldNamehash(tldName);

        addMockRegistrationStrategyToTld(parent_hash);
        addMockCommitIntent(true);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.mint(tldOwner, tldName);

        vm.prank(sldOwner);
        sld.purchaseSingleDomain("test", bytes32(0x0), 365, parent_hash, emptyArr, sldOwner);

        bytes32 sldHash = getNamehash( parent_hash, "test");

        uint256 sldId = uint256(sldHash);

        // test.test.test
        uint256 expectedsldChildId = uint256(getNamehash(sldHash, string("test")));

        addMockRegistrationStrategyToTld(sldHash);

        vm.prank(sldsldOwner);
        sld.purchaseSingleDomain("test", bytes32(0x0), 365, sldHash, emptyArr, sldsldOwner);

        uint256 tldId = uint256(getTldNamehash(tldName));

        assertEq(tldId, uint256(parent_hash));

        bytes32 parentNamehash = sld.namehashToParentMap(sldHash);
        uint256 parentId = uint256(parentNamehash);

        address newOwnerAddress = address(0xbada55);

        vm.startPrank(sldOwner);
        sld.setRoyaltyPayoutAddress(sldId, payoutAddress);
        sld.safeTransferFrom(sldOwner, newOwnerAddress, sldId);

        (address _addr, ) = sld.royaltyInfo(expectedsldChildId, 100);

        //this should change to the new owner address
        assertEq(_addr, newOwnerAddress);
        vm.stopPrank();
    }

    function ignoretestSetRoyaltyPaymentAmountForsldParentFromsldParentOwnerApprovedAddress() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address sldsldOwner = address(0xababab);
        address payoutAddress = address(0x22886644);

        HandshakeTld tld = sld.handshakeTldContract();

        bytes32[] memory emptyArr;

        bytes32 parent_hash = getTldNamehash(tldName);

        addMockRegistrationStrategyToTld(parent_hash);
        addMockCommitIntent(true);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.mint(tldOwner, tldName);

        vm.prank(sldOwner);
        sld.purchaseSingleDomain("test", bytes32(0x0), 365, parent_hash, emptyArr, sldOwner);

        bytes32 sldHash = getNamehash( parent_hash, "test");
        
        uint256 sldId = uint256(sldHash);

        // test.test.test
        uint256 expectedsldChildId = uint256(getNamehash(sldHash, string("test")));

        addMockRegistrationStrategyToTld(sldHash);

        vm.prank(sldsldOwner);
        sld.purchaseSingleDomain("test", bytes32(0x0), 365, sldHash, emptyArr, sldsldOwner);

        uint256 tldId = uint256(getTldNamehash(tldName));

        assertEq(tldId, uint256(parent_hash));

        bytes32 parentNamehash = sld.namehashToParentMap(sldHash);
        uint256 parentId = uint256(parentNamehash);

        address approvedAddress = address(0xbada55);

        vm.prank(sldOwner);
        sld.setApprovalForAll(approvedAddress, true);

        uint256 payoutAmount = 10;

        vm.startPrank(approvedAddress);
        sld.setRoyaltyPayoutAmount(sldId, payoutAmount);

        assertEq(sld.ownerOf(expectedsldChildId), sldsldOwner, "invalid child of sld owner");

        (, uint256 amount) = sld.royaltyInfo(expectedsldChildId, 100);

        //this should change to the new owner address
        assertEq(amount, 10);
        vm.stopPrank();
    }

    function testSetRoyaltyPaymentAmountForsldParentFromNotsldParentOwnerAddress_ExpectFail()
        public
    {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address sldsldOwner = address(0xababab);
        address payoutAddress = address(0x22886644);

        HandshakeTld tld = sld.handshakeTldContract();

        bytes32[] memory emptyArr;

        bytes32 parent_hash = getTldNamehash(tldName);

        addMockRegistrationStrategyToTld(parent_hash);
        addMockCommitIntent(true);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.mint(tldOwner, tldName);

        vm.prank(sldOwner);
        sld.purchaseSingleDomain("test", bytes32(0x0), 365, parent_hash, emptyArr, msg.sender);

        bytes32 sldHash = getNamehash( parent_hash, "test");

        uint256 sldId = uint256(sldHash);

        // test.test.test
        uint256 expectedsldChildId = uint256(getNamehash(sldHash, string("test")));

        addMockRegistrationStrategyToTld(sldHash);

        vm.prank(sldsldOwner);
        sld.purchaseSingleDomain("test", bytes32(0x0), 365, sldHash, emptyArr, sldsldOwner);

        uint256 tldId = uint256(getTldNamehash(tldName));

        assertEq(tldId, uint256(parent_hash));

        bytes32 parentNamehash = sld.namehashToParentMap(sldHash);
        uint256 parentId = uint256(parentNamehash);

        address notApprovedAddress = address(0xbada55);

        uint256 payoutAmount = 10;

        vm.startPrank(notApprovedAddress);
        vm.expectRevert("ERC721: invalid token ID");
        sld.setRoyaltyPayoutAmount(sldId, payoutAmount);
        vm.stopPrank();
    }

    function testGetSubdomainDetailsValidationCheckShouldPassIfArrayLengthsAllTheSame(
        uint8 _arrayLength
    ) public {
        address[] memory recipients = new address[](_arrayLength);
        uint256[] memory parentIds = new uint256[](_arrayLength);
        string[] memory labels = new string[](_arrayLength);
        uint256[] memory registrationLengths = new uint256[](_arrayLength);
        bytes32[][] memory proofs = new bytes32[][](_arrayLength);

        addMockRegistrationStrategyToTldWithPrice(bytes32(0x0), 0);
        sld.getSubdomainDetails(recipients, parentIds, labels, registrationLengths, proofs);
    }

    function testGetSubdomainDetailsValidationCheckShouldFailIfArrayLengthsParentIdsDifferent()
        public
    {
        address[] memory recipients = new address[](5);
        uint256[] memory parentIds = new uint256[](6);
        string[] memory labels = new string[](5);
        uint256[] memory registrationLengths = new uint256[](5);
        bytes32[][] memory proofs = new bytes32[][](5);

        vm.expectRevert("array lengths are different");
        sld.getSubdomainDetails(recipients, parentIds, labels, registrationLengths, proofs);
    }

    function testGetSubdomainDetailsValidationCheckShouldFailIfArrayLengthsLabelsDifferent()
        public
    {
        address[] memory recipients = new address[](5);
        uint256[] memory parentIds = new uint256[](5);
        string[] memory labels = new string[](4);
        uint256[] memory registrationLengths = new uint256[](5);
        bytes32[][] memory proofs = new bytes32[][](5);

        vm.expectRevert("array lengths are different");
        sld.getSubdomainDetails(recipients, parentIds, labels, registrationLengths, proofs);
    }

    function testGetSubdomainDetailsValidationCheckShouldFailIfArrayLengthsRegistrationLengthsDifferent()
        public
    {
        address[] memory recipients = new address[](5);
        uint256[] memory parentIds = new uint256[](5);
        string[] memory labels = new string[](5);
        uint256[] memory registrationLengths = new uint256[](7);
        bytes32[][] memory proofs = new bytes32[][](5);

        vm.expectRevert("array lengths are different");
        sld.getSubdomainDetails(recipients, parentIds, labels, registrationLengths, proofs);
    }

    function testGetSubdomainDetailsValidationCheckShouldFailIfArrayLengthsProofsDifferent()
        public
    {
        address[] memory recipients = new address[](5);
        uint256[] memory parentIds = new uint256[](5);
        string[] memory labels = new string[](5);
        uint256[] memory registrationLengths = new uint256[](5);
        bytes32[][] memory proofs = new bytes32[][](4);

        vm.expectRevert("array lengths are different");
        sld.getSubdomainDetails(recipients, parentIds, labels, registrationLengths, proofs);
    }

    function testGetSubdomainDetailsValidationCheckShouldFailIfArrayLengthsRecipientsDifferent()
        public
    {
        address[] memory recipients = new address[](5);
        uint256[] memory parentIds = new uint256[](5);
        string[] memory labels = new string[](5);
        uint256[] memory registrationLengths = new uint256[](5);
        bytes32[][] memory proofs = new bytes32[][](4);

        vm.expectRevert("array lengths are different");
        sld.getSubdomainDetails(recipients, parentIds, labels, registrationLengths, proofs);
    }

    function testGetSubdomainDetails_single() public {
        uint256 _price = 500000000000;
        address[] memory recipients = new address[](1);
        uint256[] memory parentIds = new uint256[](1);
        string[] memory labels = new string[](1);
        uint256[] memory registrationLengths = new uint256[](1);
        bytes32[][] memory proofs = new bytes32[][](1);
        bytes32[] memory empty_array;

        string memory label = "test";
        bytes32 secret = bytes32(0x0);
        uint256 registrationLength = 365;
        bytes32 parentNamehash = bytes32(uint256(0x121212));
        address recipient = address(0x998822);

        recipients[0] = recipient;
        parentIds[0] = uint256(parentNamehash);
        labels[0] = label;
        registrationLengths[0] = registrationLength;
        proofs[0] = empty_array;

        addMockRegistrationStrategyToTldWithPrice(parentNamehash, _price);
        addMockCommitIntent(true);

        address claimant = address(0x6666);

        SubdomainDetail[] memory dets = sld.getSubdomainDetails(
            recipients,
            parentIds,
            labels,
            registrationLengths,
            proofs
        );

        assertEq(dets.length, 1, "invalid array length");
        assertEq(dets[0].Price, _price * 1000, "mismatch in price");
        assertEq(
            dets[0].Id,
            uint256(getNamehash(parentNamehash, labels[0])),
            "expected Id does not match"
        );
        assertEq(dets[0].ParentId, parentIds[0], "Parent Id does not match");
        assertEq(dets[0].Label, labels[0], "subdomain label does not match");

        assertEq(dets[0].RoyaltyAmount, 0, "royalty amount does not match");
    }

    function testGetSubdomainDetails_multiple() public {
        uint256 _price = 69420;
        address[] memory recipients = new address[](3);
        uint256[] memory parentIds = new uint256[](3);
        string[] memory labels = new string[](3);
        uint256[] memory registrationLengths = new uint256[](3);
        bytes32[][] memory proofs = new bytes32[][](3);
        bytes32[] memory empty_array;

        string memory label = "test";
        bytes32 secret = bytes32(0x0);
        uint256 registrationLength = 365;
        bytes32 parentNamehash = bytes32(uint256(0x121212));
        address recipient = address(0x998822);

        recipients[0] = recipient;
        recipients[1] = recipient;
        recipients[2] = recipient;

        parentIds[0] = uint256(parentNamehash);
        parentIds[1] = uint256(parentNamehash);
        parentIds[2] = uint256(parentNamehash);

        labels[0] = label;
        labels[1] = label;
        labels[2] = label;

        registrationLengths[0] = registrationLength;
        registrationLengths[1] = registrationLength;
        registrationLengths[2] = registrationLength;

        proofs[0] = empty_array;
        proofs[1] = empty_array;
        proofs[2] = empty_array;

        addMockRegistrationStrategyToTldWithPrice(parentNamehash, _price);
        addMockCommitIntent(true);

        SubdomainDetail[] memory dets = sld.getSubdomainDetails(
            recipients,
            parentIds,
            labels,
            registrationLengths,
            proofs
        );

        //no worry about gas optimisation in the tests.
        for (uint256 i; i < dets.length; i++) {
            assertEq(dets.length, recipients.length, "invalid array length");
            assertEq(dets[i].Price, _price * 1000, "mismatch in price");
            assertEq(
                dets[i].Id,
                uint256(getNamehash( parentNamehash, labels[i])),
                "expected Id does not match"
            );
            assertEq(dets[i].ParentId, parentIds[i], "Parent Id does not match");
            assertEq(dets[i].Label, labels[i], "subdomain label does not match");

            //royalty amount not currently set in this test.
            // so should be zero
            assertEq(dets[i].RoyaltyAmount, 0, "royalty amount does not match");
        }
    }

    function ignoretestUpdateRegistrationStrategyFromsldOwner() public {
        string memory label = "testing123";
        bytes32 secret = bytes32(0x0);
        uint256 registrationLength = 365;
        bytes32 parentNamehash = getTldNamehash("yo");

        MockRegistrationStrategy RegistrationStrategy = new MockRegistrationStrategy(10);

        addMockRegistrationStrategyToTld(parentNamehash);
        addMockCommitIntent(true);

        address tldOwner = address(0x12345679);

        HandshakeTld tld = sld.handshakeTldContract();

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.startPrank(tldOwner);
        tld.mint(tldOwner, "yo");

        vm.stopPrank();

        bytes32[] memory empty_array;
        address claimant = address(0x6666);

        vm.startPrank(claimant);
        sld.purchaseSingleDomain(
            label,
            secret,
            registrationLength,
            parentNamehash,
            empty_array,
            claimant
        );

        bytes32 childHash = getNamehash(parentNamehash, label);
        sld.setPricingStrategy(uint256(childHash), address(RegistrationStrategy));
        vm.stopPrank();
    }

    function testUpdateRegistrationStrategyFromNotsldOwner() public {
        string memory label = "testing123";
        bytes32 secret = bytes32(0x0);
        uint256 registrationLength = 365;
        bytes32 parentNamehash = getTldNamehash("yoyo");

        MockRegistrationStrategy RegistrationStrategy = new MockRegistrationStrategy(10);

        addMockRegistrationStrategyToTld(parentNamehash);
        addMockCommitIntent(true);

        address tldOwner = address(0x12345679);

        HandshakeTld tld = sld.handshakeTldContract();

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.startPrank(tldOwner);
        tld.mint(tldOwner, "yoyo");

        vm.stopPrank();

        bytes32[] memory empty_array;
        address claimant = address(0x6666);

        vm.prank(claimant);
        sld.purchaseSingleDomain(
            label,
            secret,
            registrationLength,
            parentNamehash,
            empty_array,
            claimant
        );
        vm.startPrank(address(0x22446666));
        bytes32 childHash = getNamehash(parentNamehash, label);
        vm.expectRevert("ERC721: invalid token ID");
        sld.setPricingStrategy(uint256(childHash), address(RegistrationStrategy));
        vm.stopPrank();
    }

    function testPurchaseSingleDomainGetRefundForExcess() public {
        string memory label = "test";
        bytes32 secret = bytes32(0x0);
        uint256 registrationLength = 365;
        bytes32 parentNamehash = getTldNamehash("yyyttt");

        addMockRegistrationStrategyToTldWithPrice(parentNamehash, 30); //30 dollars
        addMockCommitIntent(true);

        address tldOwner = address(0x12345dddd679);

        HandshakeTld tld = sld.handshakeTldContract();
        sld.setHandshakeWalletAddress(address(0x646464));
        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.startPrank(tldOwner);
        tld.mint(tldOwner, "yyyttt");

        vm.stopPrank();

        bytes32[] memory empty_array;
        address claimant = address(0x6666);

        MockUsdOracle oracle = new MockUsdOracle(200000000000);

        stdstore.target(address(sld)).sig("usdOracle()").checked_write(address(oracle));

        hoax(claimant, 1 ether);

        sld.purchaseSingleDomain{value: 1 ether}(
            label,
            secret,
            registrationLength,
            parentNamehash,
            empty_array,
            claimant
        );
        vm.stopPrank();

        assertEq(sld.balanceOf(claimant), 1);
        assertEq(claimant.balance, 1 ether - 15000000000000000);

        // if it's $30 then we get 0.985 ether refunded (0.015 cost price @ $2000 ether)
    }

    function testPurchaseTwoDomainGetRefundForExcess() public {
        string[] memory label = new string[](2);
        bytes32[] memory secret = new bytes32[](2);
        uint256[] memory registrationLength = new uint256[](2);
        bytes32[] memory parentNamehash = new bytes32[](2);
        bytes32[][] memory proofs = new bytes32[][](2);
        address[] memory receiver = new address[](2);

        bytes32[] memory empty_array;
        address claimant = address(0x6666);

        label[0] = "test1";
        label[1] = "test2";
        secret[0] = 0x0;
        secret[1] = 0x0;
        registrationLength[0] = 365;
        registrationLength[1] = 365;
        parentNamehash[0] = getTldNamehash("testing12345");
        parentNamehash[1] = getTldNamehash("testing98765");
        proofs[0] = empty_array;
        proofs[1] = empty_array;
        receiver[0] = claimant;
        receiver[1] = claimant;

        addMockRegistrationStrategyToTldWithPrice(parentNamehash[0], 30); //30 dollars
        addMockRegistrationStrategyToTldWithPrice(parentNamehash[1], 30); //30 dollars

        address tldOwner = address(0x12345679);
        HandshakeTld tld = sld.handshakeTldContract();
        sld.setHandshakeWalletAddress(address(0x464646));

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.startPrank(tldOwner);
        tld.mint(tldOwner, "testing12345");
        tld.mint(tldOwner, "testing98765");
        vm.stopPrank();

        addMockCommitIntent(true);
        sld.setGlobalRegistrationStrategy(address(new MockGlobalRegistrationStrategy(true)));

        MockUsdOracle oracle = new MockUsdOracle(200000000000);

        stdstore.target(address(sld)).sig("usdOracle()").checked_write(address(oracle));

        hoax(claimant, 1 ether);
        sld.purchaseMultipleSld{value: 1 ether}(
            label,
            secret,
            registrationLength,
            parentNamehash,
            receiver
        );
        vm.stopPrank();

        assertEq(sld.balanceOf(claimant), 2);
        assertEq(claimant.balance, 1 ether - 30000000000000000);

        // if it's $30 then we get 0.985 ether refunded (0.015 cost price @ $2000 ether)
    }

    function testPriceOracle2() public {
        bytes32 parentNamehash = bytes32(0x0);

        addMockRegistrationStrategyToTldWithPrice(parentNamehash, 30); //30 dollars
        addMockCommitIntent(true);

        MockUsdOracle oracle = new MockUsdOracle(183185670000);

        stdstore.target(address(sld)).sig("usdOracle()").checked_write(address(oracle));
    }

    function testMintSingleDomainCheckCheckHistory() public {
        string memory label = "";
        bytes32 secret = bytes32(0x0);
        uint256 registrationLength = 365;
        bytes32 parentNamehash = getTldNamehash("tatata");

        uint256 annualCost = 5456;

        addMockRegistrationStrategyToTldWithPrice(parentNamehash, annualCost);
        addMockCommitIntent(true);

        address tldOwner = address(0x12345dddd679);

        HandshakeTld tld = sld.handshakeTldContract();
        sld.setHandshakeWalletAddress(address(0x646464));
        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.startPrank(tldOwner);
        tld.mint(tldOwner, "tatata");

        vm.stopPrank();

        addMockOracle();

        bytes32[] memory empty_array;
        address claimant = address(0x6666);

        hoax(claimant, 1000 ether);
        sld.purchaseSingleDomain{value: 1000 ether}(
            label,
            secret,
            registrationLength,
            parentNamehash,
            empty_array,
            claimant
        );
        vm.stopPrank();

        uint256 weiValue = sld.getWeiValueOfDollar();

        emit log_named_uint("wei value", weiValue);

        assertEq(sld.balanceOf(claimant), 1);

        bytes32 namehash = getNamehash(parentNamehash, label);

        (uint80 RegistrationTime, uint80 regLength, uint96 regPrice) = sld
            .subdomainRegistrationHistory(namehash);

        assertEq(regLength, registrationLength, "registration length incorrect");
        assertEq(regPrice, annualCost * 1000, "registration price incorrect");

        uint48[10] memory prices = sld.getGuarenteedPrices(namehash);

        for (uint256 i; i < prices.length; i++) {
            assertEq(prices[i] / 1000, (i + 1) * annualCost, "annual cost incorrect");
        }
    }

    function testRegisterSubdomainForOneDollarLowestPrice_pass() public {
        string memory label = "";
        bytes32 secret = bytes32(0x0);
        uint256 registrationLength = 365;
        bytes32 parentNamehash = getTldNamehash("tatata");

        addMockRegistrationStrategyToTldWithPrice(parentNamehash, 1);
        addMockCommitIntent(true);

        address tldOwner = address(0x12345679);
        HandshakeTld tld = sld.handshakeTldContract();

        sld.setHandshakeWalletAddress(address(0x999999));

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.startPrank(tldOwner);
        tld.mint(tldOwner, "tatata");
        vm.stopPrank();

        bytes32[] memory empty_array;
        address claimant = address(0x6666);

        hoax(claimant, 0.0005 ether);
        sld.purchaseSingleDomain{value: 0.0005 ether}(
            label,
            secret,
            registrationLength,
            parentNamehash,
            empty_array,
            claimant
        );
        vm.stopPrank();

        assertEq(claimant.balance, 0);

        assertEq(sld.balanceOf(claimant), 1);
    }

    function testRenewSubdomainFromsldOwner_pass() public {
        string memory label = "";
        bytes32 secret = bytes32(0x0);
        uint256 registrationLength = 365 * 2;
        bytes32 parentNamehash = getTldNamehash("yoyo");

        uint256 annualCost = 2000;

        addMockRegistrationStrategyToTldWithPrice(parentNamehash, annualCost);
        addMockCommitIntent(true);

        addMockOracle();

        bytes32[] memory empty_array;
        address claimant = address(0x6666);
        address tldOwner = address(0x464646);

        HandshakeTld tld = sld.handshakeTldContract();
        sld.setHandshakeWalletAddress(address(0x57595351));

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.mint(tldOwner, "yoyo");

        vm.warp(6688);

        hoax(claimant, 2 ether);
        sld.purchaseSingleDomain{value: 2 ether}( //should cost 2 ether
            label,
            secret,
            registrationLength,
            parentNamehash,
            empty_array,
            claimant
        );
        vm.stopPrank();

        bytes32 namehash = getNamehash( parentNamehash, label);

        (uint80 RegistrationTime, uint80 RegistrationLength, uint96 RegistrationPrice) = sld
            .subdomainRegistrationHistory(namehash);

        emit log_named_uint("registration time", RegistrationTime);
        emit log_named_uint("registration length", RegistrationLength);
        emit log_named_uint("registration price", RegistrationPrice);
        emit log_named_uint("wei value of dollar", sld.getWeiValueOfDollar());

        uint48[10] memory rates = sld.getGuarenteedPrices(namehash);

        /*
        for (uint256 i; i < rates.length; i++) {
            emit log_named_uint("rate", rates[i]);
        }
        */

        uint256 newRegLength = 400;
        hoax(claimant, 1.095 ether);
        vm.expectRevert("Price too low");
        sld.renewSubdomain{value: 1.095 ether}(namehash, newRegLength);

        hoax(claimant, 1.096 ether);
        sld.renewSubdomain{value: 1.096 ether}(namehash, newRegLength);

        (
            uint80 NewRegistrationTime,
            uint80 NewRegistrationLength,
            uint96 NewRegistrationPrice
        ) = sld.subdomainRegistrationHistory(namehash);

        assertEq(
            NewRegistrationLength,
            RegistrationLength + newRegLength,
            "new registrationLength not correct"
        );
    }

    function testRenewNoneExistingToken_fail() public {}

    function testRenewExpiredsld_fail() public {
        string memory label = "";
        bytes32 secret = bytes32(0x0);
        uint256 registrationLength = 365;
        bytes32 parentNamehash = getTldNamehash("abc");

        uint256 annualCost = 2000;

        addMockRegistrationStrategyToTldWithPrice(parentNamehash, annualCost);
        addMockCommitIntent(true);

        addMockOracle();

        sld.setHandshakeWalletAddress(address(0x787878));
        address tldOwner = address(0x12345679);
        HandshakeTld tld = sld.handshakeTldContract();

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.startPrank(tldOwner);
        tld.mint(tldOwner, "abc");
        vm.stopPrank();

        bytes32[] memory empty_array;
        address claimant = address(0x6666);

        vm.warp(6688);

        hoax(claimant, 1 ether);
        sld.purchaseSingleDomain{value: 1 ether}( //should cost 1 ether
            label,
            secret,
            registrationLength,
            parentNamehash,
            empty_array,
            claimant
        );
        vm.stopPrank();

        vm.warp(block.timestamp + (86400 * 366));
        bytes32 namehash = getNamehash(parentNamehash, label);

        uint256 newRegLength = 400;

        hoax(claimant, 1.096 ether);
        vm.expectRevert("domain expired");
        sld.renewSubdomain{value: 1.096 ether}(namehash, newRegLength);
    }

    function testRenewSubdomainFromNotOwner_pass() public {
        string memory label = "";
        bytes32 secret = bytes32(0x0);
        uint256 registrationLength = 365 * 2;
        bytes32 parentNamehash = getTldNamehash("yo");

        uint256 annualCost = 2000;

        addMockRegistrationStrategyToTldWithPrice(parentNamehash, annualCost);
        addMockCommitIntent(true);

        address tldOwner = address(0x222);
        HandshakeTld tld = sld.handshakeTldContract();
        sld.setHandshakeWalletAddress(address(0x124578));
        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.mint(tldOwner, "yo");
        addMockOracle();

        bytes32[] memory empty_array;
        address claimant = address(0x6666);

        vm.warp(6688);

        hoax(claimant, 2 ether);
        sld.purchaseSingleDomain{value: 2 ether}( //should cost 2 ether
            label,
            secret,
            registrationLength,
            parentNamehash,
            empty_array,
            claimant
        );
        vm.stopPrank();

        bytes32 namehash = getNamehash(parentNamehash, label);

        (uint80 RegistrationTime, uint80 RegistrationLength, uint96 RegistrationPrice) = sld
            .subdomainRegistrationHistory(namehash);

        emit log_named_uint("registration time", RegistrationTime);
        emit log_named_uint("registration length", RegistrationLength);
        emit log_named_uint("registration price", RegistrationPrice);
        emit log_named_uint("wei value of dollar", sld.getWeiValueOfDollar());

        uint48[10] memory rates = sld.getGuarenteedPrices(namehash);

        for (uint256 i; i < rates.length; i++) {
            emit log_named_uint("rate", rates[i]);
        }

        address notClaimant = address(0x22446688664422);

        uint256 newRegLength = 400;
        hoax(notClaimant, 1.095 ether);
        vm.expectRevert("Price too low");
        sld.renewSubdomain{value: 1.095 ether}(namehash, newRegLength);

        hoax(notClaimant, 1.096 ether);
        sld.renewSubdomain{value: 1.096 ether}(namehash, newRegLength);

        (
            uint80 NewRegistrationTime,
            uint80 NewRegistrationLength,
            uint96 NewRegistrationPrice
        ) = sld.subdomainRegistrationHistory(namehash);

        assertEq(
            NewRegistrationLength,
            RegistrationLength + newRegLength,
            "new registrationLength not correct"
        );
    }

    function testPurchaseSingleDomainFundsGetSentToOwnerAndHandshakeWallet() public {
        string memory label = "test";
        bytes32 secret = bytes32(0x0);
        uint256 registrationLength = 365;
        bytes32 parentNamehash = getTldNamehash("yoyoyo");

        addMockRegistrationStrategyToTldWithPrice(parentNamehash, 30); //30 dollars
        addMockCommitIntent(true);

        bytes32[] memory empty_array;
        address claimant = address(0x6666);

        address tldOwner = address(0x12345679);

        HandshakeTld tld = sld.handshakeTldContract();

        sld.setHandshakeWalletAddress(address(0x888888));

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.startPrank(tldOwner);
        tld.mint(tldOwner, "yoyoyo");
        vm.stopPrank();

        MockUsdOracle oracle = new MockUsdOracle(200000000000);

        stdstore.target(address(sld)).sig("usdOracle()").checked_write(address(oracle));

        hoax(claimant, 1 ether);

        sld.purchaseSingleDomain{value: 1 ether}(
            label,
            secret,
            registrationLength,
            parentNamehash,
            empty_array,
            claimant
        );
        vm.stopPrank();

        assertEq(sld.balanceOf(claimant), 1);

        emit log_named_uint("tld balance", tldOwner.balance); //14250000000000000
        emit log_named_uint("handshake balance", sld.handshakeWalletPayoutAddress().balance); //750000000000000

        assertEq(claimant.balance, 1 ether - 15000000000000000);
        assertEq(tldOwner.balance, 14250000000000000);
        assertEq(sld.handshakeWalletPayoutAddress().balance, 750000000000000);
        assertEq(
            tldOwner.balance + sld.handshakeWalletPayoutAddress().balance + claimant.balance,
            1 ether
        );
    }

    function testSetGlobalRegistrationStrategyFromContractOwner_pass() public {
        MockGlobalRegistrationStrategy strategy = new MockGlobalRegistrationStrategy(true);

        sld.setGlobalRegistrationStrategy(address(strategy));

        assertEq(
            address(sld.contractRegistrationStrategy()),
            address(strategy),
            "registration strategy not successfully set"
        );
    }

    function testSetGlobalRegistrationStrategyFromNotContractOwner_fail() public {
        MockGlobalRegistrationStrategy strategy = new MockGlobalRegistrationStrategy(true);

        vm.prank(address(0x64646464644));
        vm.expectRevert("Ownable: caller is not the owner");
        sld.setGlobalRegistrationStrategy(address(strategy));
    }

    function testSetGlobalRegistrationStrategyIncorrectInterfaceFromContractOwner_fail() public {
        MockRegistrationStrategy strategy = new MockRegistrationStrategy(100);
        vm.expectRevert("IGlobalRegistrationRules interface not supported");
        sld.setGlobalRegistrationStrategy(address(strategy));
    }

    function testSetHandshakeWalletAddressFromContractOwner_pass() public {
        address addr = address(0x2244661122);
        vm.startPrank(sld.owner());
        sld.setHandshakeWalletAddress(addr);

        assertEq(sld.handshakeWalletPayoutAddress(), addr);
    }

    function testSetHandshakeWalletAddressToZeroAddressFromContractOwner_fail() public {
        address addr = address(0);
        vm.startPrank(sld.owner());
        vm.expectRevert("cannot set to zero address");
        sld.setHandshakeWalletAddress(addr);
    }

    function testSetHandshakeWalletAddressFromNotContractOwner_fail() public {
        vm.startPrank(address(0x5555555555));
        address addr = address(0x2244661122);
        vm.expectRevert("Ownable: caller is not the owner");
        sld.setHandshakeWalletAddress(addr);
    }
}

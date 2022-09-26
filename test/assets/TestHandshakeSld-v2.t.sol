// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import {Namehash} from "utils/Namehash.sol";
import "contracts/HandshakeSld-v2.sol";
import "utils/Namehash.sol";
import "interfaces/ITldClaimManager.sol";
import "interfaces/ISldRegistrationManager.sol";
import "test/mocks/MockClaimManager.sol";
import "test/mocks/MockCommitIntent.sol";
import "test/mocks/MockLabelValidator.sol";
import "test/mocks/MockHandshakeTld.sol";
import "test/mocks/MockRegistrationStrategy.sol";
import "test/mocks/MockUsdOracle.sol";
import "test/mocks/MockGlobalRegistrationStrategy.sol";
import "test/mocks/MockCommitIntent.sol";
import "test/mocks/MockSldRegistrationManager.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "interfaces/ICommitIntent.sol";

contract TestHandshakeSld_v2 is Test {
    error MissingRegistrationStrategy();

    // test
    bytes32 constant TEST_TLD_NAMEHASH =
        0x04f740db81dc36c853ab4205bddd785f46e79ccedca351fc6dfcbd8cc9a33dd6;
    // test.test
    bytes32 constant TEST_sld_NAMEHASH =
        0x28f4f6752878f66fd9e3626dc2a299ee01cfe269be16e267e71046f1022271cb;
    // test.test.test
    bytes32 constant TEST_SUB_NAMEHASH =
        0xab4320f3c1dd20a2fc23e7b0dda6f37afbf916136c4797a99caad59e740d9494;

    using stdStorage for StdStorage;

    HandshakeSld_v2 sld;
    MockHandshakeTld tld;
    MockSldRegistrationManager manager;

    function setUp() public {
        tld = new MockHandshakeTld();
        manager = new MockSldRegistrationManager();
        sld = new HandshakeSld_v2(tld, manager);
    }

    function testMintSldFromRegistryAddress_success() public {
        vm.startPrank(address(manager));

        address to = address(0x123456789);
        bytes32 tldNamehash = bytes32(uint256(0x224466));
        bytes32 sldNamehash = bytes32(uint256(0x446688));

        sld.registerSld(to, tldNamehash, sldNamehash);

        assertEq(sld.ownerOf(uint256(sldNamehash)), to, "not owner of token");
        assertEq(sld.balanceOf(to), 1, "balance incorrect");
    }

    function testMintSldFromNotRegistryAddress_fail() public {
        vm.startPrank(address(0x66666));

        address to = address(0x123456789);
        bytes32 tldNamehash = bytes32(uint256(0x224466));
        bytes32 sldNamehash = bytes32(uint256(0x446688));

        vm.expectRevert("not authorised");
        sld.registerSld(to, tldNamehash, sldNamehash);
    }

    function testMintDuplicateSld_fail() public {
        vm.startPrank(address(manager));

        address to = address(0x123456789);
        bytes32 tldNamehash = bytes32(uint256(0x224466));
        bytes32 sldNamehash = bytes32(uint256(0x446688));

        sld.registerSld(to, tldNamehash, sldNamehash);

        assertEq(sld.ownerOf(uint256(sldNamehash)), to, "not owner of token");
        assertEq(sld.balanceOf(to), 1, "balance incorrect");

        vm.expectRevert("ERC721: token already minted");
        sld.registerSld(to, tldNamehash, sldNamehash);
    }

    function testCheckParentNamehashIsCorrectAfterMint() public {
        vm.startPrank(address(manager));

        address to = address(0x123456789);
        bytes32 tldNamehash = bytes32(uint256(0x224466));
        bytes32 sldNamehash = bytes32(uint256(0x446688));

        sld.registerSld(to, tldNamehash, sldNamehash);

        assertEq(sld.ownerOf(uint256(sldNamehash)), to, "not owner of token");
        assertEq(sld.balanceOf(to), 1, "balance incorrect");
    }

    function testCheckLabelToNamehashIsCorrectAfterMint() public {
        vm.startPrank(address(manager));
        console.log("manager address", address(manager));
        address to = address(0x123456789);
        bytes32 tldNamehash = bytes32(uint256(0x224466));
        bytes32 sldNamehash = bytes32(uint256(0x446688));

        tld.register(address(manager), uint256(tldNamehash));

        sld.registerSld(to, tldNamehash, sldNamehash);

        assertEq(
            sld.namehashToParentMap(sldNamehash),
            tldNamehash,
            "namehash for parent incorrect"
        );
    }

    function testSetRoyaltyPaymentAddressForTldFromTldOwnerAddress() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address payoutAddress = address(0x22886644);

        bytes32[] memory emptyArr;

        bytes32 parent_hash = Namehash.getTldNamehash(tldName);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.register(tldOwner, tldName);

        bytes32 subdomainNamehash = Namehash.getNamehash(parent_hash, "test");
        vm.prank(address(manager));
        sld.registerSld(sldOwner, parent_hash, subdomainNamehash);

        // test.test
        uint256 expectedsldId = uint256(subdomainNamehash);

        assertEq(expectedsldId, uint256(TEST_sld_NAMEHASH));

        uint256 tldId = uint256(parent_hash);
        assertEq(tldId, uint256(TEST_TLD_NAMEHASH));

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

        bytes32[] memory emptyArr;

        bytes32 parent_hash = Namehash.getTldNamehash(tldName);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.register(tldOwner, tldName);

        bytes32 subdomainNamehash = Namehash.getNamehash(parent_hash, "test");
        vm.prank(address(manager));
        sld.registerSld(sldOwner, parent_hash, subdomainNamehash);

        // test.test
        uint256 expectedsldId = uint256(subdomainNamehash);

        assertEq(expectedsldId, uint256(TEST_sld_NAMEHASH));

        uint256 tldId = uint256(parent_hash);
        assertEq(tldId, uint256(TEST_TLD_NAMEHASH));

        (address _addr, ) = sld.royaltyInfo(expectedsldId, 100);
        assertEq(_addr, tldOwner);
        vm.stopPrank();
    }

    function testSetRoyaltyPaymentAddressThenTransferTld_AddressShouldResetToNewOwner() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address payoutAddress = address(0x22886644);

        bytes32[] memory emptyArr;

        bytes32 parent_hash = Namehash.getTldNamehash(tldName);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.register(tldOwner, tldName);

        bytes32 subdomainNamehash = Namehash.getNamehash(parent_hash, "test");
        vm.prank(address(manager));
        sld.registerSld(sldOwner, parent_hash, subdomainNamehash);

        // test.test
        uint256 expectedsldId = uint256(subdomainNamehash);

        assertEq(expectedsldId, uint256(TEST_sld_NAMEHASH));

        uint256 tldId = uint256(parent_hash);
        assertEq(tldId, uint256(TEST_TLD_NAMEHASH));

        address newTldOwner = address(0x553311);

        vm.startPrank(tldOwner);
        sld.setRoyaltyPayoutAddress(tldId, payoutAddress);
        (address _addr, ) = sld.royaltyInfo(expectedsldId, 100);
        assertEq(_addr, payoutAddress);
        tld.safeTransferFrom(tldOwner, newTldOwner, tldId);
        vm.stopPrank();

        (_addr, ) = sld.royaltyInfo(expectedsldId, 100);
        assertEq(_addr, newTldOwner);
    }

    function testSetRoyaltyPaymentAddressForTldFromTldOwnerApprovedAddress() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address payoutAddress = address(0x22886644);

        bytes32[] memory emptyArr;

        bytes32 parent_hash = Namehash.getTldNamehash(tldName);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.register(tldOwner, tldName);

        bytes32 subdomainNamehash = Namehash.getNamehash(parent_hash, "test");
        vm.prank(address(manager));
        sld.registerSld(sldOwner, parent_hash, subdomainNamehash);

        // test.test
        uint256 expectedsldId = uint256(subdomainNamehash);

        assertEq(expectedsldId, uint256(TEST_sld_NAMEHASH));

        uint256 tldId = uint256(parent_hash);
        assertEq(tldId, uint256(TEST_TLD_NAMEHASH));

        address approvedAddress = address(0x558822);

        vm.prank(tldOwner);
        tld.setApprovalForAll(approvedAddress, true);
        vm.startPrank(approvedAddress);
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

        bytes32[] memory emptyArr;

        bytes32 parent_hash = Namehash.getTldNamehash(tldName);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.register(tldOwner, tldName);

        bytes32 subdomainNamehash = Namehash.getNamehash(parent_hash, "test");
        vm.startPrank(address(manager));
        sld.registerSld(sldOwner, parent_hash, subdomainNamehash);
        vm.stopPrank();
        // test.test
        uint256 expectedsldId = uint256(subdomainNamehash);

        assertEq(expectedsldId, uint256(TEST_sld_NAMEHASH));

        uint256 tldId = uint256(parent_hash);
        assertEq(tldId, uint256(TEST_TLD_NAMEHASH));

        address approvedAddress = address(0x558822);

        address notTldOwner = address(0x9988332211);
        vm.startPrank(notTldOwner);
        vm.expectRevert("not authorised");
        sld.setRoyaltyPayoutAddress(tldId, payoutAddress);

        vm.stopPrank();
    }

    function testSetRoyaltyPaymentAmountForTldFromTldOwnerAddress_pass() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address payoutAddress = address(0x22886644);

        bytes32[] memory emptyArr;

        bytes32 parent_hash = Namehash.getTldNamehash(tldName);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.register(tldOwner, tldName);

        bytes32 subdomainNamehash = Namehash.getNamehash(parent_hash, "test");
        vm.prank(address(manager));
        sld.registerSld(sldOwner, parent_hash, subdomainNamehash);

        // test.test
        uint256 expectedsldId = uint256(subdomainNamehash);

        assertEq(expectedsldId, uint256(TEST_sld_NAMEHASH));

        uint256 tldId = uint256(parent_hash);
        assertEq(tldId, uint256(TEST_TLD_NAMEHASH));

        uint256 royaltyPercent = 10;

        vm.prank(tldOwner);
        sld.setRoyaltyPayoutAmount({_id: tldId, _amount: royaltyPercent});
        (, uint256 amount) = sld.royaltyInfo(expectedsldId, 100);

        assertEq(amount, royaltyPercent, "incorrect royalty amount");
        vm.stopPrank();
    }

    function testSetRoyaltyPaymentAmountForTldNotSet_ShouldReturnZero() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address payoutAddress = address(0x22886644);

        bytes32[] memory emptyArr;

        bytes32 parent_hash = Namehash.getTldNamehash(tldName);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.register(tldOwner, tldName);

        bytes32 subdomainNamehash = Namehash.getNamehash(parent_hash, "test");
        vm.prank(address(manager));
        sld.registerSld(sldOwner, parent_hash, subdomainNamehash);

        // test.test
        uint256 expectedsldId = uint256(subdomainNamehash);

        assertEq(expectedsldId, uint256(TEST_sld_NAMEHASH));

        uint256 tldId = uint256(parent_hash);
        assertEq(tldId, uint256(TEST_TLD_NAMEHASH));

        (, uint256 amount) = sld.royaltyInfo(expectedsldId, 100);

        assertEq(amount, 0, "incorrect royalty amount, should be zero");
        vm.stopPrank();
    }

    function testSetRoyaltyPaymentAmountForTldFromTldOwnerApprovedAddress() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address payoutAddress = address(0x22886644);

        bytes32[] memory emptyArr;

        bytes32 parent_hash = Namehash.getTldNamehash(tldName);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.register(tldOwner, tldName);

        bytes32 subdomainNamehash = Namehash.getNamehash(parent_hash, "test");
        vm.prank(address(manager));
        sld.registerSld(sldOwner, parent_hash, subdomainNamehash);

        // test.test
        uint256 expectedsldId = uint256(subdomainNamehash);

        assertEq(expectedsldId, uint256(TEST_sld_NAMEHASH));

        uint256 tldId = uint256(parent_hash);
        assertEq(tldId, uint256(TEST_TLD_NAMEHASH));

        address approvedAddress = address(0x558822);

        vm.prank(tldOwner);
        tld.setApprovalForAll(approvedAddress, true);
        vm.startPrank(approvedAddress);
        uint256 royaltyPercent = 1;
        sld.setRoyaltyPayoutAmount(tldId, royaltyPercent);

        (address addy, uint256 amount) = sld.royaltyInfo(expectedsldId, 300);

        assertEq(amount, 3, "incorrect royalty amount");

        vm.stopPrank();
    }

    function testSetRoyaltyPaymentAmountForTldFromNotTldOwnerAddress_ExpectFail() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address payoutAddress = address(0x22886644);

        bytes32[] memory emptyArr;

        bytes32 parent_hash = Namehash.getTldNamehash(tldName);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.register(tldOwner, tldName);

        bytes32 subdomainNamehash = Namehash.getNamehash(parent_hash, "test");
        vm.prank(address(manager));
        sld.registerSld(sldOwner, parent_hash, subdomainNamehash);

        // test.test
        uint256 expectedsldId = uint256(subdomainNamehash);

        assertEq(expectedsldId, uint256(TEST_sld_NAMEHASH));

        uint256 tldId = uint256(parent_hash);
        assertEq(tldId, uint256(TEST_TLD_NAMEHASH));

        address notTldOwner = address(0x558822);

        vm.startPrank(notTldOwner);
        vm.expectRevert("not authorised");
        sld.setRoyaltyPayoutAddress(tldId, payoutAddress);

        vm.stopPrank();
    }

    function testSetRoyaltyPaymentAmountForTldFromTldOwnerAddressOver10Percent_expectFail() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address payoutAddress = address(0x22886644);

        bytes32[] memory emptyArr;

        bytes32 parent_hash = Namehash.getTldNamehash(tldName);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.register(tldOwner, tldName);

        bytes32 subdomainNamehash = Namehash.getNamehash(parent_hash, "test");
        vm.prank(address(manager));
        sld.registerSld(sldOwner, parent_hash, subdomainNamehash);

        // test.test
        uint256 expectedsldId = uint256(subdomainNamehash);

        assertEq(expectedsldId, uint256(TEST_sld_NAMEHASH));

        uint256 tldId = uint256(parent_hash);
        assertEq(tldId, uint256(TEST_TLD_NAMEHASH));

        uint256 royaltyPercent = 11;

        vm.startPrank(tldOwner);
        vm.expectRevert("10% maximum royalty on SLD");
        sld.setRoyaltyPayoutAmount({_id: tldId, _amount: royaltyPercent});
        (, uint256 amount) = sld.royaltyInfo(expectedsldId, 100);

        vm.stopPrank();
    }

    function testAddRegistrationStrategyToTldDomain_pass() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address payoutAddress = address(0x22886644);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.startPrank(tldOwner);
        tld.register(tldOwner, tldName);

        MockRegistrationStrategy strategy = new MockRegistrationStrategy(0);

        bytes32 parentNamehash = Namehash.getTldNamehash(tldName);
        tld.addApprovedAddress(tldOwner, uint256(parentNamehash));
        sld.setRegistrationStrategy(uint256(parentNamehash), strategy);

        ISldRegistrationStrategy expectedStrategy = sld.getRegistrationStrategy(parentNamehash);
        assertEq(address(expectedStrategy), address(strategy), "incorrects strategy");
    }

    function testAddRegistrationStrategyToTldNotOwner_fail() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address notTldOwner = address(0x232323);
        address payoutAddress = address(0x22886644);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.register(tldOwner, tldName);

        MockRegistrationStrategy strategy = new MockRegistrationStrategy(0);

        bytes32 parentNamehash = Namehash.getTldNamehash(tldName);

        vm.startPrank(notTldOwner);
        vm.expectRevert("not authorised");
        sld.setRegistrationStrategy(uint256(parentNamehash), strategy);

        vm.expectRevert(MissingRegistrationStrategy.selector);
        ISldRegistrationStrategy expectedStrategy = sld.getRegistrationStrategy(parentNamehash);
    }
}

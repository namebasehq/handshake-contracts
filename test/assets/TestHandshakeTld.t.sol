// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import {HandshakeSld} from "contracts/HandshakeSld.sol";
import {HandshakeTld} from "contracts/HandshakeTld.sol";
import {Namehash} from "utils/Namehash.sol";
import "test/mocks/MockRegistrationStrategy.sol";
import "test/mocks/MockClaimManager.sol";
import "test/mocks/MockSldRegistrationManager.sol";
import "test/mocks/MockMetadataService.sol";
import "test/mocks/MockGlobalRegistrationStrategy.sol";
import "interfaces/ICommitIntent.sol";
import "interfaces/ITldClaimManager.sol";
import "interfaces/IMetadataService.sol";
import "interfaces/ISldRegistrationStrategy.sol";
import "interfaces/ISldRegistrationManager.sol";
import "interfaces/ILabelValidator.sol";
import "test/mocks/MockLabelValidator.sol";
import "mocks/MockRegistrationStrategy.sol";
import "interfaces/IResolver.sol";

contract TestHandshakeTld is Test {
    using stdStorage for StdStorage;
    HandshakeTld tld;
    HandshakeSld sld;

    ITldClaimManager claimManager;
    ISldRegistrationManager registrationManager;
    ILabelValidator validator;

    IResolver defaultResolver;

    ISldRegistrationStrategy defaultRegistrationStrategy;

    // test
    bytes32 constant TEST_TLD_NAMEHASH =
        0x04f740db81dc36c853ab4205bddd785f46e79ccedca351fc6dfcbd8cc9a33dd6;
    // test.test
    bytes32 constant TEST_SLD_NAMEHASH =
        0x28f4f6752878f66fd9e3626dc2a299ee01cfe269be16e267e71046f1022271cb;
    // test.test.test
    bytes32 constant TEST_SUB_NAMEHASH =
        0xab4320f3c1dd20a2fc23e7b0dda6f37afbf916136c4797a99caad59e740d9494;

    function setUp() public {
        claimManager = new MockClaimManager();

        MockMetadataService metadata = new MockMetadataService("base_url/");
        tld = new HandshakeTld(claimManager);
        sld = new HandshakeSld(tld);

        registrationManager = new MockSldRegistrationManager(
            tld,
            new MockGlobalRegistrationStrategy(true, 1 ether)
        );

        sld.setRegistrationManager(registrationManager);
        sld.setMetadataContract(metadata);
        tld.setMetadataContract(metadata);

        defaultResolver = IResolver(address(0x888888));
        defaultRegistrationStrategy = ISldRegistrationStrategy(address(0x123456789));
    }

    function getNamehash(bytes32 _parentHash, string memory _label) private pure returns (bytes32) {
        return Namehash.getNamehash(_parentHash, _label);
    }

    function getTldNamehash(string memory _label) private pure returns (bytes32) {
        return Namehash.getTldNamehash(_label);
    }

    function testMintFromUnauthorisedAddress() public {
        string memory domain = "test";

        vm.expectRevert("not authorised");
        tld.registerWithResolver(address(0x1339), domain, defaultRegistrationStrategy);
    }

    function testMintFromAuthoriseAddress() public {
        string memory domain = "test";
        uint256 tldId = uint256(getTldNamehash(domain));
        //https://book.getfoundry.sh/reference/forge-std/std-storage
        stdstore.target(address(tld)).sig("claimManager()").checked_write(address(this));

        tld.registerWithResolver(address(0x1339), domain, defaultRegistrationStrategy);
        assertEq(address(0x1339), tld.ownerOf(tldId));
    }

    function testMintCheckLabelToHashMapUpdated() public {
        string memory domain = "testtesttest";
        bytes32 namehash = getTldNamehash(domain);

        //https://book.getfoundry.sh/reference/forge-std/std-storage
        stdstore.target(address(tld)).sig("claimManager()").checked_write(address(this));

        tld.registerWithResolver(address(0x1339), domain, defaultRegistrationStrategy);

        assertEq(domain, tld.namehashToLabelMap(namehash));
        assertEq(domain, tld.namehashToLabelMap(namehash));
        assertEq(domain, tld.name(namehash)); //alias view function
    }

    function testUpdateRoyaltyPercentageFromOwnerWallet() public {
        //10 percent is the max royalty
        uint256 tenPercentRoyalty = 100;

        tld.setRoyaltyPayoutAmount(tenPercentRoyalty);
        (, uint256 amount) = tld.royaltyInfo(0, 100);
        assertEq(amount, 10);
    }

    function testUpdateRoyaltyPercentageFromNotOwnerWalletExpectFail() public {
        uint256 fivePercentRoyalty = 50;
        vm.startPrank(address(0x3333));
        vm.expectRevert("Ownable: caller is not the owner");
        tld.setRoyaltyPayoutAmount(fivePercentRoyalty);
        vm.stopPrank();
    }

    function testUpdateRoyaltyPayoutAddressFromOwnerWallet() public {
        address payoutAddress = address(0x66991122);

        tld.setRoyaltyPayoutAddress(payoutAddress);
        (address addr, ) = tld.royaltyInfo(0, 100);
        assertEq(payoutAddress, addr);
    }

    function testUpdateRoyaltyToZeroAddressExpectFail() public {
        address zeroAddress = address(0);
        vm.expectRevert("cannot set to zero address");
        tld.setRoyaltyPayoutAddress(zeroAddress);
    }

    function testUpdateRoyaltyPayoutAddressFromNotOwnerWalletExpectFail() public {
        address payoutAddress = address(0x66991122);
        vm.startPrank(address(0x998877));
        vm.expectRevert("Ownable: caller is not the owner");
        tld.setRoyaltyPayoutAddress(payoutAddress);
        vm.stopPrank();
    }

    function testUpdateRoyaltyAbove100_which_is_10_percent_ExpectFail() public {
        uint256 tenPointOnePercentRoyalty = 101;

        vm.expectRevert("10% maximum royalty on TLD");
        tld.setRoyaltyPayoutAmount(tenPointOnePercentRoyalty);
    }

    function testUpdateRoyaltyPercentageToSmallestNumberExpectZeroReturned() public {
        //this is 0.1%
        uint256 zeroPointOnePercent = 1;

        tld.setRoyaltyPayoutAmount(zeroPointOnePercent);
        (, uint256 amount) = tld.royaltyInfo(0, 100);
        assertEq(amount, 0);
    }

    function testUpdateRoyaltyPercentageToLargestNumberSaleAmountToSmallestNumbertenPercentRoyalty()
        public
    {
        //10 percent is the max royalty
        uint256 tenPercentRoyalty = 100;
        uint256 smallestSaleAmount = 1;

        tld.setRoyaltyPayoutAmount(tenPercentRoyalty);
        (, uint256 amount) = tld.royaltyInfo(0, smallestSaleAmount);
        assertEq(amount, 0);
    }

    function testUpdateTldClaimManagerFromNotOwner_fail() public {
        address claimManager = address(0x123456);
        vm.startPrank(address(0x998877));
        vm.expectRevert("Ownable: caller is not the owner");
        tld.setTldClaimManager(ITldClaimManager(claimManager));
        vm.stopPrank();
    }

    function testAddRegistrationStrategyToTldDomain_pass() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        bytes32 parentNamehash = Namehash.getTldNamehash(tldName);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));
        tld.setDefaultResolver(defaultResolver);

        vm.startPrank(tldOwner);
        tld.registerWithResolver(tldOwner, tldName, defaultRegistrationStrategy);

        MockRegistrationStrategy strategy = new MockRegistrationStrategy(0);

        tld.setRegistrationStrategy(parentNamehash, strategy);

        ISldRegistrationStrategy expectedStrategy = tld.registrationStrategy(parentNamehash);
        assertEq(address(expectedStrategy), address(strategy), "incorrects strategy");
    }

    function testAddRegistrationStrategyToTldDomainByApprovedAddress_pass() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address approved = address(0x420420);
        bytes32 parentNamehash = Namehash.getTldNamehash(tldName);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));
        tld.setDefaultResolver(defaultResolver);

        vm.startPrank(tldOwner);
        tld.registerWithResolver(tldOwner, tldName, defaultRegistrationStrategy);
        tld.setApprovalForAll(approved, true);

        vm.stopPrank();
        vm.startPrank(approved);
        MockRegistrationStrategy strategy = new MockRegistrationStrategy(0);

        tld.setRegistrationStrategy(parentNamehash, strategy);

        ISldRegistrationStrategy expectedStrategy = tld.registrationStrategy(parentNamehash);
        assertEq(address(expectedStrategy), address(strategy), "incorrects strategy");
    }

    function testAddRegistrationStrategyToTldNotOwner_fail() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address notTldOwner = address(0x232323);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));
        tld.setDefaultResolver(defaultResolver);

        vm.prank(tldOwner);
        tld.registerWithResolver(tldOwner, tldName, defaultRegistrationStrategy);

        MockRegistrationStrategy strategy = new MockRegistrationStrategy(0);

        bytes32 parentNamehash = Namehash.getTldNamehash(tldName);

        vm.startPrank(notTldOwner);
        vm.expectRevert("not approved or owner");
        tld.setRegistrationStrategy(parentNamehash, strategy);

        assertEq(
            address(tld.registrationStrategy(parentNamehash)),
            address(defaultRegistrationStrategy)
        );
    }

    function testRegisterTldDefaultRegistrationStrategyIsSet() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        bytes32 parentNamehash = Namehash.getTldNamehash(tldName);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));
        tld.setDefaultResolver(defaultResolver);

        vm.startPrank(tldOwner);
        tld.registerWithResolver(tldOwner, tldName, defaultRegistrationStrategy);

        assertEq(
            address(tld.registrationStrategy(parentNamehash)),
            address(defaultRegistrationStrategy)
        );
    }

    function testRegisterTldDefaultResolverIsSet() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        bytes32 parentNamehash = Namehash.getTldNamehash(tldName);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));
        tld.setDefaultResolver(defaultResolver);

        vm.startPrank(tldOwner);
        tld.registerWithResolver(tldOwner, tldName, defaultRegistrationStrategy);

        assertEq(address(tld.tokenResolverMap(parentNamehash)), address(defaultResolver));
    }

    function testSetRoyaltyPayoutAndAddressFromOwner() public {
        address royaltyAddress = address(0x123456);
        uint256 royaltyAmount = 100;

        tld.setRoyaltyPayoutAmountAndAddress(royaltyAddress, royaltyAmount);

        assertEq(tld.royaltyPayoutAddress(), royaltyAddress);
        assertEq(tld.royaltyPayoutAmount(), royaltyAmount);
    }

    function testSetRoyaltyPayoutAndAddressFromNotOwner_fail() public {
        address royaltyAddress = address(0x123456);
        uint256 royaltyAmount = 100;

        vm.startPrank(address(0x998877));
        vm.expectRevert("Ownable: caller is not the owner");
        tld.setRoyaltyPayoutAmountAndAddress(royaltyAddress, royaltyAmount);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import {HandshakeTld, HandshakeSld} from "contracts/HandshakeSld.sol";
import {Namehash} from "utils/Namehash.sol";
import "test/mocks/MockRegistrationStrategy.sol";
import "test/mocks/MockClaimManager.sol";
import "test/mocks/MockSldRegistrationManager.sol";
import "test/mocks/MockMetadataService.sol";
import "interfaces/ICommitIntent.sol";
import "interfaces/ITldClaimManager.sol";
import "interfaces/IMetadataService.sol";
import "interfaces/ISldRegistrationStrategy.sol";
import "interfaces/ISldRegistrationManager.sol";
import "interfaces/ILabelValidator.sol";
import "test/mocks/MockLabelValidator.sol";

contract TestHandshakeTld is Test {
    using stdStorage for StdStorage;
    HandshakeTld tld;
    HandshakeSld sld;

    ITldClaimManager claimManager;
    ISldRegistrationManager registrationManager;
    ILabelValidator validator;

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
        registrationManager = new MockSldRegistrationManager();
        MockMetadataService metadata = new MockMetadataService("base_url/");
        tld = new HandshakeTld(claimManager, metadata);
        sld = new HandshakeSld(tld, metadata);
        sld.setRegistrationManager(registrationManager);
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
        tld.register(address(0x1339), domain);
    }

    function testMintFromAuthoriseAddress() public {
        string memory domain = "test";
        uint256 tldId = uint256(getTldNamehash(domain));
        //https://book.getfoundry.sh/reference/forge-std/std-storage
        stdstore.target(address(tld)).sig("claimManager()").checked_write(address(this));

        tld.register(address(0x1339), domain);
        assertEq(address(0x1339), tld.ownerOf(tldId));
    }

    function testMintCheckLabelToHashMapUpdated() public {
        string memory domain = "test";
        bytes32 namehash = getTldNamehash(domain);

        //https://book.getfoundry.sh/reference/forge-std/std-storage
        stdstore.target(address(tld)).sig("claimManager()").checked_write(address(this));

        tld.register(address(0x1339), domain);

        assertEq(domain, tld.namehashToLabelMap(namehash));
    }

    function testUpdateDefaultSldRegistrationStrategyFromTldOwner() public {
        string memory domain = "test";
        uint256 tldId = uint256(getTldNamehash(domain));
        bytes32 tldHash = bytes32(tldId);
        address tldOwnerAddr = address(0x6942);
        MockRegistrationStrategy sldRegistrationStrategy = new MockRegistrationStrategy(0);
        //https://book.getfoundry.sh/reference/forge-std/std-storage
        stdstore.target(address(sld.handshakeTldContract())).sig("claimManager()").checked_write(
            address(this)
        );
        stdstore.target(address(sld)).sig("handshakeTldContract()").checked_write(
            address(sld.handshakeTldContract())
        );
        sld.handshakeTldContract().register(tldOwnerAddr, domain);
        assertEq(tldId, uint256(TEST_TLD_NAMEHASH), "parent id not as expected");

        emit log_named_address(
            "owner is",
            sld.handshakeTldContract().ownerOf(uint256(TEST_TLD_NAMEHASH))
        );

        vm.startPrank(tldOwnerAddr);
        sld.setRegistrationStrategy(tldId, sldRegistrationStrategy);

        assertEq(address(sld.getRegistrationStrategy(tldHash)), address(sldRegistrationStrategy));

        vm.stopPrank();
    }

    //TODO: check if this duplicate test on Sld contract
    function testUpdateDefaultSldRegistrationStrategyFromNotTldOwner() public {
        string memory domain = "test";
        bytes32 tldHash = getTldNamehash(domain);

        address tldOwnerAddr = address(0x6942);
        address notTldOwnerAddr = address(0x004204);
        address sldRegistrationStrategy = address(0x133737);

        //https://book.getfoundry.sh/reference/forge-std/std-storage
        stdstore.target(address(sld.handshakeTldContract())).sig("claimManager()").checked_write(
            address(this)
        );

        sld.handshakeTldContract().register(tldOwnerAddr, domain);

        vm.startPrank(notTldOwnerAddr);

        // Tld.updateSldPricingStrategy(bytes32(tldId), ISldRegistrationStrategy(sldRegistrationStrategy));
        stdstore.target(address(sld)).sig("handshakeTldContract()").checked_write(
            address(sld.handshakeTldContract())
        );
        vm.expectRevert("not authorised");
        sld.setRegistrationStrategy(
            uint256(tldHash),
            ISldRegistrationStrategy(sldRegistrationStrategy)
        );
        vm.stopPrank();
    }

    function testUpdateDefaultSldRegistrationStrategyFromNoneExistingTld() public {}

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
}

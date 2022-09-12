// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import {HandshakeTld, HandshakeSld} from "contracts/HandshakeSld.sol";
import { Namehash } from "utils/Namehash.sol";
import "contracts/HandshakeRegistry.sol";
import "test/mocks/mockRegistrationStrategy.sol";
import "interfaces/ITldClaimManager.sol";
import "interfaces/IMetadataService.sol";
import "interfaces/ISldRegistrationStrategy.sol";

contract HandshakeTldTests is Test {
    using stdStorage for StdStorage;
    HandshakeRegistry registry;
    HandshakeTld Tld;
    HandshakeSld Sld;

    // test
    bytes32 constant TEST_TLD_NAMEHASH = 0x04f740db81dc36c853ab4205bddd785f46e79ccedca351fc6dfcbd8cc9a33dd6;
    // test.test
    bytes32 constant TEST_SLD_NAMEHASH = 0x28f4f6752878f66fd9e3626dc2a299ee01cfe269be16e267e71046f1022271cb;
    // test.test.test
    bytes32 constant TEST_SUB_NAMEHASH = 0xab4320f3c1dd20a2fc23e7b0dda6f37afbf916136c4797a99caad59e740d9494;

    function setUp() public {
        registry = new HandshakeRegistry();
        Tld = new HandshakeTld(address(this));
        Sld = new HandshakeSld(registry, Tld);
    }

    // TODO: swap param order
    function getNamehash(string memory _label, bytes32 _parentHash) private pure returns (bytes32) {
        return Namehash.getNamehash(_label, _parentHash);
    }

    function getTldNamehash(string memory _label) private pure returns (bytes32) {
        return Namehash.getTldNamehash(_label);
    }

    function testMintFromUnauthorisedAddress() public {
        string memory domain = "test";
        uint256 tldId = uint256(getTldNamehash(domain));
        vm.expectRevert("not authorised");
        Tld.mint(address(0x1339), domain);
    }

    function testMintFromAuthoriseAddress() public {
        string memory domain = "test";
        uint256 tldId = uint256(getTldNamehash(domain));
        //https://book.getfoundry.sh/reference/forge-std/std-storage
        stdstore.target(address(Tld)).sig("ClaimManager()").checked_write(address(this));

        Tld.mint(address(0x1339), domain);
        assertEq(address(0x1339), Tld.ownerOf(tldId));
    }

    function testMintCheckLabelToHashMapUpdated() public {
        string memory domain = "test";
        bytes32 namehash = getTldNamehash(domain);
        uint256 tldId = uint256(namehash);
        //https://book.getfoundry.sh/reference/forge-std/std-storage
        stdstore.target(address(Tld)).sig("ClaimManager()").checked_write(address(this));

        Tld.mint(address(0x1339), domain);

        assertEq(domain, Tld.NamehashToLabelMap(namehash));
    }

    function testUpdateDefaultSldRegistrationStrategyFromTldOwner() public {
        string memory domain = "test";
        uint256 tldId = uint256(getTldNamehash(domain));
        bytes32 tldHash = bytes32(tldId);
        address tldOwnerAddr = address(0x6942);
        MockRegistrationStrategy sldRegistrationStrategy = new MockRegistrationStrategy(0);
        //https://book.getfoundry.sh/reference/forge-std/std-storage
        stdstore.target(address(Sld.HandshakeTldContract())).sig("ClaimManager()").checked_write(
            address(this)
        );
        stdstore.target(address(Sld)).sig("HandshakeTldContract()").checked_write(
            address(Sld.HandshakeTldContract())
        );
        Sld.HandshakeTldContract().mint(tldOwnerAddr, domain);
        assertEq(
            tldId,
            uint256(TEST_TLD_NAMEHASH),
            "parent id not as expected"
        );

        emit log_named_address(
            "owner is",
            Sld.HandshakeTldContract().ownerOf(uint256(TEST_TLD_NAMEHASH))
        );

        vm.startPrank(tldOwnerAddr);
        Sld.setPricingStrategy(tldId, address(sldRegistrationStrategy));

        assertEq(address(Sld.getPricingStrategy(tldHash)), address(sldRegistrationStrategy));

        vm.stopPrank();
    }

    function testUpdateDefaultSldRegistrationStrategyFromNotTldOwner() public {
        string memory domain = "test";
        bytes32 tldHash = getTldNamehash(domain);
        uint256 tldId = uint256(tldHash);
        address tldOwnerAddr = address(0x6942);
        address notTldOwnerAddr = address(0x004204);
        address sldRegistrationStrategy = address(0x133737);

        //https://book.getfoundry.sh/reference/forge-std/std-storage
        stdstore.target(address(Sld.HandshakeTldContract())).sig("ClaimManager()").checked_write(
            address(this)
        );

        Sld.HandshakeTldContract().mint(tldOwnerAddr, domain);

        vm.startPrank(notTldOwnerAddr);

        // Tld.updateSldPricingStrategy(bytes32(tldId), ISldRegistrationStrategy(sldRegistrationStrategy));
        stdstore.target(address(Sld)).sig("HandshakeTldContract()").checked_write(
            address(Sld.HandshakeTldContract())
        );
        vm.expectRevert("ERC721: invalid token ID");
        Sld.setPricingStrategy(uint256(tldHash), sldRegistrationStrategy);
        vm.stopPrank();
    }

    function testUpdateDefaultSldRegistrationStrategyFromNoneExistingTld() public {}

    function testUpdateRoyaltyPercentageFromOwnerWallet() public {
        //10 percent is the max royalty
        uint256 tenPercentRoyalty = 100;

        Tld.setRoyaltyPayoutAmount(tenPercentRoyalty);
        (, uint256 amount) = Tld.royaltyInfo(0, 100);
        assertEq(amount, 10);
    }

    function testUpdateRoyaltyPercentageFromNotOwnerWalletExpectFail() public {
        uint256 fivePercentRoyalty = 50;
        vm.startPrank(address(0x3333));
        vm.expectRevert("Ownable: caller is not the owner");
        Tld.setRoyaltyPayoutAmount(fivePercentRoyalty);
        vm.stopPrank();
    }

    function testUpdateRoyaltyPayoutAddressFromOwnerWallet() public {
        address payoutAddress = address(0x66991122);

        Tld.setRoyaltyPayoutAddress(payoutAddress);
        (address addr, ) = Tld.royaltyInfo(0, 100);
        assertEq(payoutAddress, addr);
    }

    function testUpdateRoyaltyToZeroAddressExpectFail() public {
        address zeroAddress = address(0);
        vm.expectRevert("cannot set to zero address");
        Tld.setRoyaltyPayoutAddress(zeroAddress);
    }

    function testUpdateRoyaltyPayoutAddressFromNotOwnerWalletExpectFail() public {
        address payoutAddress = address(0x66991122);
        vm.startPrank(address(0x998877));
        vm.expectRevert("Ownable: caller is not the owner");
        Tld.setRoyaltyPayoutAddress(payoutAddress);
        vm.stopPrank();
    }

    function testUpdateRoyaltyAbove100_which_is_10_percent_ExpectFail() public {
        uint256 tenPointOnePercentRoyalty = 101;

        vm.expectRevert("10% maximum royalty on TLD");
        Tld.setRoyaltyPayoutAmount(tenPointOnePercentRoyalty);
    }

    function testUpdateRoyaltyPercentageToSmallestNumberExpectZeroReturned() public {
        //this is 0.1%
        uint256 zeroPointOnePercent = 1;

        Tld.setRoyaltyPayoutAmount(zeroPointOnePercent);
        (, uint256 amount) = Tld.royaltyInfo(0, 100);
        assertEq(amount, 0);
    }

    function testUpdateRoyaltyPercentageToLargestNumberSaleAmountToSmallestNumbertenPercentRoyalty()
        public
    {
        //10 percent is the max royalty
        uint256 tenPercentRoyalty = 100;
        uint256 smallestSaleAmount = 1;

        Tld.setRoyaltyPayoutAmount(tenPercentRoyalty);
        (, uint256 amount) = Tld.royaltyInfo(0, smallestSaleAmount);
        assertEq(amount, 0);
    }
}
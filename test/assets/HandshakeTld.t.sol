// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import "contracts/HandshakeTld.sol";
import "contracts/HandshakeSld.sol";
import "test/mocks/mockRegistrationStrategy.sol";
import "interfaces/ITldClaimManager.sol";
import "interfaces/IMetadataService.sol";
import "interfaces/ISldRegistrationStrategy.sol";

contract HandshakeTldTests is Test {
    using stdStorage for StdStorage;
    HandshakeTld Tld;
    HandshakeSld Sld;

    function setUp() public {
        Tld = new HandshakeTld(address(this));
        Sld = new HandshakeSld();
    }

    function testMintFromUnauthorisedAddress() public {
        string memory domain = "test";
        uint256 tldId = uint256(bytes32(keccak256(abi.encodePacked(domain))));
        vm.expectRevert("not authorised");
        Tld.mint(address(0x1339), domain);
    }

    function testMintFromAuthoriseAddress() public {
        string memory domain = "test";
        uint256 tldId = uint256(bytes32(keccak256(abi.encodePacked(domain))));
        //https://book.getfoundry.sh/reference/forge-std/std-storage
        stdstore.target(address(Tld)).sig("ClaimManager()").checked_write(address(this));

        Tld.mint(address(0x1339), domain);
        assertEq(address(0x1339), Tld.ownerOf(tldId));
    }

    function testMintCheckLabelToHashMapUpdated() public {
        string memory domain = "test";
        bytes32 namehash = bytes32(keccak256(abi.encodePacked(domain)));
        uint256 tldId = uint256(namehash);
        //https://book.getfoundry.sh/reference/forge-std/std-storage
        stdstore.target(address(Tld)).sig("ClaimManager()").checked_write(address(this));

        Tld.mint(address(0x1339), domain);

        assertEq(domain, Tld.NamehashToLabelMap(namehash));
    }

    function testUpdateDefaultSldRegistrationStrategyFromTldOwner() public {
        string memory domain = "test";
        uint256 tldId = uint256(bytes32(keccak256(abi.encodePacked(domain))));
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
            70622639689279718371527342103894932928233838121221666359043189029713682937432,
            "parent id not as expected"
        );

        emit log_named_address(
            "owner is",
            Sld.HandshakeTldContract().ownerOf(
                70622639689279718371527342103894932928233838121221666359043189029713682937432
            )
        );
        vm.startPrank(tldOwnerAddr);
        Sld.setPricingStrategy(tldHash, address(sldRegistrationStrategy));

        assertEq(address(Sld.getPricingStrategy(tldHash)), address(sldRegistrationStrategy));

        vm.stopPrank();
    }

    function testUpdateDefaultSldRegistrationStrategyFromNotTldOwner() public {
        string memory domain = "test";
        bytes32 tldHash = bytes32(keccak256(abi.encodePacked(domain)));
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
        vm.expectRevert("not approved or owner of parent domain");
        Sld.setPricingStrategy(tldHash, sldRegistrationStrategy);
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
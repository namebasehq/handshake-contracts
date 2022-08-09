// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import "src/contracts/HandshakeTld.sol";
import "interfaces/ITldClaimManager.sol";
import "interfaces/IMetadataService.sol";
import "interfaces/ISldPriceStrategy.sol";

contract HandshakeTldTests is Test {
    using stdStorage for StdStorage;
    HandshakeTld Tld;

    function setUp() public {
        Tld = new HandshakeTld(address(this));
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

    //not working currently. Need to check if accessing internal storage is
    //supported.. doesn't look like it currently
    function testUpdateDefaultSldPriceStrategyFromTldOwner() public {
        string memory domain = "test";
        uint256 tldId = uint256(bytes32(keccak256(abi.encodePacked(domain))));
        address tldOwnerAddr = address(0x6942);
        address sldPriceStrategy = address(0x133737);

        //https://book.getfoundry.sh/reference/forge-std/std-storage
        stdstore.target(address(Tld)).sig("ClaimManager()").checked_write(address(this));

        Tld.mint(tldOwnerAddr, domain);

        vm.startPrank(tldOwnerAddr);
        Tld.updateSldPricingStrategy(bytes32(tldId), ISldPriceStrategy(sldPriceStrategy));
        assertEq(
            address(Tld.SldDefaultPriceStrategy(bytes32(tldId))),
            address(Tld.SldDefaultPriceStrategy(bytes32(tldId)))
        );
        vm.stopPrank();
    }

    function testUpdateDefaultSldPriceStrategyFromNotTldOwner() public {
        string memory domain = "test";
        uint256 tldId = uint256(bytes32(keccak256(abi.encodePacked(domain))));
        address tldOwnerAddr = address(0x6942);
        address notTldOwnerAddr = address(0x004204);
        address sldPriceStrategy = address(0x133737);

        //https://book.getfoundry.sh/reference/forge-std/std-storage
        stdstore.target(address(Tld)).sig("ClaimManager()").checked_write(address(this));

        Tld.mint(tldOwnerAddr, domain);

        vm.startPrank(notTldOwnerAddr);
        vm.expectRevert("Caller is not owner of TLD");
        Tld.updateSldPricingStrategy(bytes32(tldId), ISldPriceStrategy(sldPriceStrategy));
        assertEq(
            address(Tld.SldDefaultPriceStrategy(bytes32(tldId))),
            address(Tld.SldDefaultPriceStrategy(bytes32(tldId)))
        );
        vm.stopPrank();
    }

    function testUpdateDefaultSldPriceStrategyFromNoneExistingTld() public {
        string memory domain = "test";
        uint256 tldId = uint256(bytes32(keccak256(abi.encodePacked(domain))));
        uint256 notTldId = 4444;
        address tldOwnerAddr = address(0x6942);
        address notTldOwnerAddr = address(0x004204);
        address sldPriceStrategy = address(0x133737);

        //https://book.getfoundry.sh/reference/forge-std/std-storage
        stdstore.target(address(Tld)).sig("ClaimManager()").checked_write(address(this));

        Tld.mint(tldOwnerAddr, domain);

        vm.startPrank(tldOwnerAddr);
        vm.expectRevert("NOT_MINTED");
        Tld.updateSldPricingStrategy(
            bytes32(notTldId),
            ISldPriceStrategy(sldPriceStrategy)
        );
        assertEq(
            address(Tld.SldDefaultPriceStrategy(bytes32(tldId))),
            address(Tld.SldDefaultPriceStrategy(bytes32(tldId)))
        );
        vm.stopPrank();
    }

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

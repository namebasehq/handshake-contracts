// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import "src/contracts/assets/TldNft.sol";
import "interfaces/registration/ITldClaimManager.sol";
import "interfaces/data/IMetadataService.sol";
import "interfaces/registration/ISldPriceStrategy.sol";


contract TldClaimManagerTests is Test {

    using stdStorage for StdStorage;
    TldNft Tld;

    function setUp() public {
        Tld = new TldNft();
    }


    function testMintFromUnauthorisedAddress() public {

        vm.expectRevert("not authorised");
        Tld.mint(address(0x1339), bytes32(uint256(0x1337)));
       
    }

    function testMintFromAuthoriseAddress() public {
        //https://book.getfoundry.sh/reference/forge-std/std-storage
        stdstore.target(address(Tld))
                .sig("ClaimManager()")
                .checked_write(address(this));
       
        Tld.mint(address(0x1339), bytes32(uint256(0x1337)));       
    }

    function testUpdateMetadataFromOwner() public {
        Tld.setMetadataContract(IMetadataService(address(0x1337)));
        assertEq(address(0x1337), address(Tld.Metadata()));
    }


    function testUpdateMetadataFromNoneOwner() public {
        vm.startPrank(address(0x6666));
        vm.expectRevert("Ownable: caller is not the owner");       
        Tld.setMetadataContract(IMetadataService(address(0x1337)));
        vm.stopPrank();
    }

    //not working currently. Need to check if accessing internal storage is 
    //supported.. doesn't look like it currently
    function testUpdateDefaultSldPriceStrategyFromTldOwner() public {

        uint256 tldId = 666;
        address tldOwnerAddr = address(0x6942);
        address sldPriceStrategy = address(0x133737);

       //https://book.getfoundry.sh/reference/forge-std/std-storage
        stdstore.target(address(Tld))
                .sig("ClaimManager()")
                .checked_write(address(this));
       
        Tld.mint(tldOwnerAddr, bytes32(tldId));    

        vm.startPrank(tldOwnerAddr);
        Tld.updateSldPricingStrategy(bytes32(tldId), ISldPriceStrategy(sldPriceStrategy));
        assertEq(address(Tld.SldDefaultPriceStrategy(bytes32(tldId))), address(Tld.SldDefaultPriceStrategy(bytes32(tldId))));
        vm.stopPrank();

    }

    function testUpdateDefaultSldPriceStrategyFromNotTldOwner() public {

        uint256 tldId = 666;
        address tldOwnerAddr = address(0x6942);
        address notTldOwnerAddr = address(0x004204);
        address sldPriceStrategy = address(0x133737);

       //https://book.getfoundry.sh/reference/forge-std/std-storage
        stdstore.target(address(Tld))
                .sig("ClaimManager()")
                .checked_write(address(this));
       
        Tld.mint(tldOwnerAddr, bytes32(tldId));    

        vm.startPrank(notTldOwnerAddr);
        vm.expectRevert("Caller is not owner of TLD");
        Tld.updateSldPricingStrategy(bytes32(tldId), ISldPriceStrategy(sldPriceStrategy));
        assertEq(address(Tld.SldDefaultPriceStrategy(bytes32(tldId))), address(Tld.SldDefaultPriceStrategy(bytes32(tldId))));
        vm.stopPrank();
    }

    function testUpdateDefaultSldPriceStrategyFromNoneExistingTld() public {
        uint256 tldId = 666;
        uint256 notTldId = 4444;
        address tldOwnerAddr = address(0x6942);
        address notTldOwnerAddr = address(0x004204);
        address sldPriceStrategy = address(0x133737);

       //https://book.getfoundry.sh/reference/forge-std/std-storage
        stdstore.target(address(Tld))
                .sig("ClaimManager()")
                .checked_write(address(this));
       
        Tld.mint(tldOwnerAddr, bytes32(tldId));    

        vm.startPrank(tldOwnerAddr);
        vm.expectRevert("NOT_MINTED");
        Tld.updateSldPricingStrategy(bytes32(notTldId), ISldPriceStrategy(sldPriceStrategy));
        assertEq(address(Tld.SldDefaultPriceStrategy(bytes32(tldId))), address(Tld.SldDefaultPriceStrategy(bytes32(tldId))));
        vm.stopPrank();
    }

}

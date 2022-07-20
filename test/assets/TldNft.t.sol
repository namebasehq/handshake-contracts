// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import "src/contracts/assets/TldNft.sol";


contract TldClaimManagerTests is Test {

    TldNft Tld;

    function setUp() public {
        Tld = new TldNft();
    }


    function testMintFromUnauthorisedAddress() public {

        vm.expectRevert("not authorised");
        Tld.mint(address(this), bytes32(uint256(0x1337)));
       
    }

}

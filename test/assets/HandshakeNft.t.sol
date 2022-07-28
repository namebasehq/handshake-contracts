// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import "src/contracts/assets/HandshakeERC721.sol";

contract TestNft is HandshakeERC721 {

    constructor() HandshakeERC721("TEST", "TEST"){

    }

    function testAuthorised(uint256 _id) public isApprovedOrOwner(_id) {

        //only need an empty method here to test the modifier.
    }

    function mint(address _addr, uint256 _id) public {
        _mint(_addr, _id);
    }
}

contract HandshakeNftTests is Test {

    using stdStorage for StdStorage;
    TestNft nft;

    function setUp() public {
        nft = new TestNft();
    }


    //tests for the isApprovedOrOwner modifier
    function testOwnerIsAuthorised() public {
        uint256 id = 11235813;

        nft.mint(address(this), id);
        nft.testAuthorised(id);
    }

    function testAuthorisedForAllAddressIsAuthorised() public {
        uint256 id = 11235813;
        address approved_address = address(0x12345678);

        nft.mint(address(this), id);

        nft.setApprovalForAll(approved_address, true);

        vm.startPrank(approved_address);
        nft.testAuthorised(id);

        vm.stopPrank();
    }

    function testAuthorisedForAllThenRemoveAddressIsNotAuthorised() public {
        uint256 id = 11235813;
        address approved_address = address(0x12345678);

        nft.mint(address(this), id);

        nft.setApprovalForAll(approved_address, true);
        nft.setApprovalForAll(approved_address, false);

        vm.startPrank(approved_address);
        vm.expectRevert("Not approved or owner");
        nft.testAuthorised(id);

        vm.stopPrank();
    }

    function testAuthorisedForIdAddressIsAuthorised() public {
        uint256 id = 11235813;
        address approved_address = address(0x12345678);

        nft.mint(address(this), id);

        nft.approve(approved_address, id);

        vm.startPrank(approved_address);
        nft.testAuthorised(id);

        vm.stopPrank();
    }

    function testAuthorisedForIdThenRemoveAddressIsAuthorised() public {
        uint256 id = 11235813;
        address approved_address = address(0x12345678);

        nft.mint(address(this), id);

        nft.approve(approved_address, id);
        nft.approve(address(0), id);

        vm.startPrank(approved_address);
        vm.expectRevert("Not approved or owner");
        nft.testAuthorised(id);

        vm.stopPrank();
    }

    function testAuthorisedOnTokenThatDoesNotExist() public {
        uint256 id = 11235813;
        address approved_address = address(0x12345678);

        nft.mint(address(this), id);

        vm.expectRevert("NOT_MINTED");
        nft.testAuthorised(id + 1);
    }

    //</end> tests for the isApprovedOrOwner modifier


}
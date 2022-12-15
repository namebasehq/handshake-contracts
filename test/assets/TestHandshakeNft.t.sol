// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import "contracts/HandshakeNft.sol";

import "test/mocks/MockMetadataService.sol";
import "test/mocks/MockCommitIntent.sol";
import "test/mocks/MockLabelValidator.sol";
import "test/mocks/MockMetadataService.sol";

contract TestNft is HandshakeNft {
    constructor() HandshakeNft("HNSNFT", "HandshakeNFT") {}

    function checkAuthorised(uint256 _id) public onlyApprovedOrOwner(_id) {
        // only need an empty method here to test the modifier.
    }

    function mint(address _addr, uint256 _id) public {
        _mint(_addr, _id);
    }
}

contract TestHandshakeNft is Test {
    using stdStorage for StdStorage;
    TestNft nft;

    function setUp() public {
        nft = new TestNft();
    }

    // tests for the onlyApprovedOrOwner modifier
    function testOwnerIsAuthorised() public {
        uint256 id = 11235813;

        nft.mint(address(this), id);
        nft.checkAuthorised(id);
    }

    function testAuthorisedForAllAddressIsAuthorised() public {
        uint256 id = 11235813;
        address approved_address = address(0x12345678);

        nft.mint(address(this), id);

        nft.setApprovalForAll(approved_address, true);

        vm.startPrank(approved_address);
        nft.checkAuthorised(id);

        vm.stopPrank();
    }

    function testAuthorisedForAllThenRemoveAddressIsNotAuthorised() public {
        uint256 id = 11235813;
        address approved_address = address(0x12345678);

        nft.mint(address(this), id);

        nft.setApprovalForAll(approved_address, true);
        nft.setApprovalForAll(approved_address, false);

        vm.startPrank(approved_address);
        vm.expectRevert("not approved or owner");
        nft.checkAuthorised(id);

        vm.stopPrank();
    }

    function testAuthorisedForIdAddressIsAuthorised() public {
        uint256 id = 11235813;
        address approved_address = address(0x12345678);

        nft.mint(address(this), id);

        nft.approve(approved_address, id);

        vm.startPrank(approved_address);
        nft.checkAuthorised(id);

        vm.stopPrank();
    }

    function testAuthorisedForIdThenRemoveAddressIsAuthorised() public {
        uint256 id = 11235813;
        address approved_address = address(0x12345678);

        nft.mint(address(this), id);

        nft.approve(approved_address, id);
        nft.approve(address(0), id);

        vm.startPrank(approved_address);
        vm.expectRevert("not approved or owner");
        nft.checkAuthorised(id);

        vm.stopPrank();
    }

    function testAuthorisedOnTokenThatDoesNotExist() public {
        uint256 id = 11235813;

        nft.mint(address(this), id);

        vm.expectRevert("not approved or owner");
        nft.checkAuthorised(id + 1);
    }

    function testUpdateMetadataWithCorrectServiceFromOwnerWallet() public {
        string memory value = "return value";
        MockMetadataService metadata = new MockMetadataService(value);
        nft.setMetadataContract(metadata);
        assertEq(value, nft.tokenURI(0));
    }

    function testUpdateMetadataWithCorrectServiceFromNotOwnerWalletExpectFail() public {
        string memory value = "return value";
        MockMetadataService metadata = new MockMetadataService(value);

        vm.startPrank(address(0x1337));
        vm.expectRevert("Ownable: caller is not the owner");
        nft.setMetadataContract(metadata);
        vm.stopPrank();
    }

    function testUpdateMetadataWithWrongInterfaceFromOwnerWalletExpectFail() public {
        MockCommitIntent notMetadata = new MockCommitIntent(true);

        vm.expectRevert("does not implement tokenUri method");
        nft.setMetadataContract(IMetadataService(address(notMetadata)));
    }

    //</end> tests for the onlyApprovedOrOwner modifier
}

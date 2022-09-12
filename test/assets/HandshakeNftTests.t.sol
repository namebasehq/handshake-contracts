// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import "contracts/HandshakeNFT.sol";
import "contracts/HandshakeRegistry.sol";

import "test/mocks/mockMetadataService.sol";
import "test/mocks/mockCommitIntent.sol";

contract TestNft is HandshakeNFT {
    
    constructor(HandshakeRegistry _registry) HandshakeNFT("TEST", "TEST") {}

    function checkAuthorised(uint256 _id) public onlyApprovedOrOwner(_id) {
        // only need an empty method here to test the modifier.
    }

    function mint(address _addr, uint256 _id) public {
        _mint(_addr, _id);
    }
}

contract HandshakeNftTests is Test {
    using stdStorage for StdStorage;
    HandshakeRegistry registry;
    TestNft nft;

    function setUp() public {
        registry = new HandshakeRegistry();
        nft = new TestNft(registry);
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

        vm.expectRevert("ERC721: invalid token ID");
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
        MockMetadataService metadata = new MockMetadataService("");

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

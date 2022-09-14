// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

import "interfaces/ICommitIntent.sol";
import "contracts/SldCommitIntent.sol";

contract TestSldCommitIntent is Test {
    ICommitIntent internal intent;

    function setUp() public {
        intent = new SldCommitIntent();
    }

    function testMissedCommitDeadline() public {
        //Arrange
        bytes32 node = bytes32(uint256(666));
        uint256 startBlock = 10;
        uint256 maxBlocks = intent.MaxBlockWaitForCommit();
        bytes32 secret = bytes32(uint256(42424242));
        intent.updateMinBlockWaitForCommit(0);

        //Act
        bytes32 combinedHash = keccak256(abi.encodePacked(node, secret, address(this)));
        vm.roll(startBlock);
        intent.commitIntent(combinedHash);
        vm.roll(startBlock + maxBlocks);

        //Assert
        bool allowed = intent.allowedCommit(node, secret, address(this));
        assertFalse(allowed);
    }

    function testCommitIntentNotAllowedBeforeMinBlockWait() public {
        //Arrange
        bytes32 node = bytes32(uint256(666));
        uint256 startBlock = 10;
        uint256 maxBlocks = intent.MaxBlockWaitForCommit();
        uint256 minBlocks = 2;
        bytes32 secret = bytes32(uint256(42424242));
        intent.updateMinBlockWaitForCommit(minBlocks);

        //Act
        bytes32 combinedHash = keccak256(abi.encodePacked(node, secret, address(this)));
        vm.roll(startBlock);
        intent.commitIntent(combinedHash);
        vm.roll(startBlock + minBlocks - 1);

        //Assert
        bool allowed = intent.allowedCommit(node, secret, address(this));
        assertFalse(allowed);

        vm.roll(startBlock + minBlocks + 1);
        allowed = intent.allowedCommit(node, secret, address(this));
        assertTrue(allowed);
    }

    function testMissedCommitDeadlineThenDifferentWalletCommit() public {
        //Arrange
        bytes32 node = bytes32(uint256(666));
        uint256 startBlock = 10;
        uint256 maxBlocks = intent.MaxBlockWaitForCommit();
        bytes32 secret = bytes32(uint256(42424242));
        intent.updateMinBlockWaitForCommit(0);

        //Act
        bytes32 combinedHash = keccak256(abi.encodePacked(node, secret, address(this)));
        vm.roll(startBlock);
        intent.commitIntent(combinedHash);
        vm.roll(startBlock + maxBlocks);

        //Assert
        bool allowed = intent.allowedCommit(node, secret, address(this));
        assertFalse(allowed);

        address newAddress = address(0x22);
        bytes32 combinedHash2 = keccak256(abi.encodePacked(node, secret, newAddress));

        vm.roll(startBlock + maxBlocks + 2);
        vm.prank(newAddress);
        intent.commitIntent(combinedHash2);
        allowed = intent.allowedCommit(node, secret, newAddress);
        assertTrue(allowed, "second address should be allowed");
    }

    function testNotMissedCommitDeadlineThenDifferentWalletCommit() public {
        //Arrange
        bytes32 node = bytes32(uint256(666));
        uint256 startBlock = 10;
        uint256 maxBlocks = intent.MaxBlockWaitForCommit();
        bytes32 secret = bytes32(uint256(42424242));
        uint256 minWait = 2;
        intent.updateMinBlockWaitForCommit(minWait);

        //Act
        bytes32 combinedHash = keccak256(abi.encodePacked(node, secret, address(this)));
        vm.roll(startBlock);
        intent.commitIntent(combinedHash);
        vm.roll(startBlock + maxBlocks - 8);

        //Assert
        bool allowed = intent.allowedCommit(node, secret, address(this));
        assertTrue(allowed);

        address newAddress = address(0x22);
        bytes32 combinedHash2 = keccak256(abi.encodePacked(node, secret, newAddress));

        vm.roll(startBlock + maxBlocks - 5);
        vm.prank(newAddress);
        intent.commitIntent(combinedHash2);
        vm.roll(block.number + minWait);
        bool allowed2 = intent.allowedCommit(node, secret, newAddress);
        allowed = intent.allowedCommit(node, secret, address(this));

        assertTrue(allowed, "first address should be allowed");
        assertTrue(allowed2, "second address should be allowed");
    }

    function testBeatCommitDeadline() public {
        //Arrange
        bytes32 node = bytes32(uint256(667));
        bytes32 secret = bytes32(uint256(2432423));

        uint256 startBlock = 10;
        uint256 maxBlocks = intent.MaxBlockWaitForCommit();
        intent.updateMinBlockWaitForCommit(0);

        //Act
        bytes32 combinedHash = keccak256(abi.encodePacked(node, secret, address(this)));
        vm.roll(startBlock);
        intent.commitIntent(combinedHash);
        vm.roll(startBlock + maxBlocks - 1);

        //Assert
        bool allowed = intent.allowedCommit(node, secret, address(this));
        assertTrue(allowed);
    }

    function testBeatCommitDeadlineCheckWithOtherAccount() public {
        //Arrange
        bytes32 node = bytes32(uint256(667));
        uint256 startBlock = 1000;
        uint256 maxBlocks = intent.MaxBlockWaitForCommit();
        emit log_named_uint("max block wait: ", maxBlocks);
        bytes32 secret = bytes32(uint256(420420));
        intent.updateMinBlockWaitForCommit(0);

        //Act
        bytes32 combinedHash = keccak256(abi.encodePacked(node, secret, address(this)));
        vm.roll(startBlock);
        intent.commitIntent(node);
        vm.roll(startBlock + maxBlocks - 1);

        //Assert

        bool allowed = intent.allowedCommit(node, secret, address(0x1337));

        assertFalse(allowed);
    }

    function testBeatCommitDeadlineWithTwoNodes() public {
        //Arrange
        bytes32 node = bytes32(uint256(777));
        bytes32 node2 = bytes32(uint256(888));

        bytes32 secret = bytes32(uint256(22222));
        bytes32 secret2 = bytes32(uint256(1212121212));

        uint256 startBlock = 10;
        uint256 maxBlocks = intent.MaxBlockWaitForCommit();
        intent.updateMinBlockWaitForCommit(0);

        //Act
        vm.roll(startBlock);
        bytes32[] memory arr = new bytes32[](2);
        arr[0] = keccak256(abi.encodePacked(node, secret, address(this)));
        arr[1] = keccak256(abi.encodePacked(node2, secret2, address(this)));
        intent.multiCommitIntent(arr);

        vm.roll(startBlock + maxBlocks - 1);

        //Assert
        bool allowed = intent.allowedCommit(node, secret, address(this));
        bool allowed2 = intent.allowedCommit(node2, secret2, address(this));
        assertTrue(allowed && allowed2);
    }

    function testCommitIntentWhenActiveCommitExists() public {
        //Arrange
        bytes32 node = bytes32(uint256(667));
        uint256 startBlock = 10;
        intent.updateMinBlockWaitForCommit(0);

        //Act
        vm.roll(startBlock);
        intent.commitIntent(node);

        vm.roll(startBlock + 2);

        //Assert
        vm.expectRevert("already been committed");
        intent.commitIntent(node);
    }

    function testCommitIntentWhenExpiredCommitExistsWithDifferentWallets() public {
        //Arrange
        bytes32 node = bytes32(uint256(667));
        bytes32 secret = bytes32(uint256(22222));

        uint256 startBlock = 10;
        uint256 maxBlocks = intent.MaxBlockWaitForCommit();

        intent.updateMinBlockWaitForCommit(0);

        address user = address(0x08);

        bytes32 combinedHash = keccak256(abi.encodePacked(node, secret, address(this)));
        bytes32 combinedHash2 = keccak256(abi.encodePacked(node, secret, user));

        //Act
        vm.roll(startBlock);
        intent.commitIntent(combinedHash);

        vm.roll(startBlock + maxBlocks + 1);
        bool allowed = intent.allowedCommit(node, secret, user);

        //Assert
        assertFalse(allowed);

        vm.prank(user);
        intent.commitIntent(combinedHash2);
        bool allowed2 = intent.allowedCommit(node, secret, user);
        assertTrue(allowed2);
    }

    function testCommitIntentWhenExpiredCommitExistsWithSameWallet() public {
        //Arrange
        bytes32 node = bytes32(uint256(667));
        bytes32 secret = bytes32(uint256(22222));

        uint256 startBlock = 10;
        uint256 maxBlocks = intent.MaxBlockWaitForCommit();

        address user = address(0x08);

        intent.updateMinBlockWaitForCommit(0);

        bytes32 combinedHash = keccak256(abi.encodePacked(node, secret, user));
        vm.startPrank(user);
        //Act
        vm.roll(startBlock);
        intent.commitIntent(combinedHash);

        vm.roll(startBlock + maxBlocks + 1);
        bool allowed = intent.allowedCommit(node, secret, user);

        //Assert
        assertFalse(allowed);

        intent.commitIntent(combinedHash);
        bool allowed2 = intent.allowedCommit(node, secret, user);
        assertTrue(allowed2);
    }

    function testCommitIntentWhenExpiredCommitExists() public {
        //Arrange
        bytes32 node = bytes32(uint256(667));
        bytes32 secret = bytes32(uint256(22222));

        uint256 startBlock = 10;
        uint256 maxBlocks = intent.MaxBlockWaitForCommit();

        address user = address(0x08);

        bytes32 combinedHash = keccak256(abi.encodePacked(node, secret, address(this)));
        bytes32 combinedHash2 = keccak256(abi.encodePacked(node, secret, user));
        intent.updateMinBlockWaitForCommit(0);

        //Act
        vm.roll(startBlock);
        intent.commitIntent(combinedHash);

        vm.roll(startBlock + maxBlocks + 1);
        bool allowed = intent.allowedCommit(node, secret, address(this));

        //Assert
        assertFalse(allowed);

        vm.prank(user);
        intent.commitIntent(combinedHash2);
        bool allowed2 = intent.allowedCommit(node, secret, user);
        assertTrue(allowed2);
    }

    function testChangeCommitDeadlineByOwner() public {
        //Arrange
        uint256 maxBlocks = intent.MaxBlockWaitForCommit();

        //Act
        intent.updateMaxBlockWaitForCommit(maxBlocks + 20);

        //Assert
        uint256 newMaxBlocks = intent.MaxBlockWaitForCommit();
        assertEq(maxBlocks + 20, newMaxBlocks);
    }

    function testChangeCommitDeadlineByNotOwner() public {
        //Arrange
        uint256 maxBlocks = intent.MaxBlockWaitForCommit();

        //Act
        vm.startPrank(address(0x10)); //change to other calling address
        vm.expectRevert("Ownable: caller is not the owner");

        //Assert
        intent.updateMaxBlockWaitForCommit(maxBlocks + 20);
        vm.stopPrank();
    }

    function testChangeMinWaitByOwner() public {
        //Arrange
        uint256 newMinBlocks = intent.MinBlockWaitForCommit() + 3;

        //Act
        intent.updateMinBlockWaitForCommit(newMinBlocks);

        //Assert
        assertEq(intent.MinBlockWaitForCommit(), newMinBlocks);
    }

    function testChangeMinWaitByNotOwner() public {
        //Arrange
        uint256 minBlocks = intent.MaxBlockWaitForCommit();

        //Act
        vm.startPrank(address(0x10)); //change to other calling address
        vm.expectRevert("Ownable: caller is not the owner");

        //Assert
        intent.updateMinBlockWaitForCommit(minBlocks + 1);
        vm.stopPrank();
    }
}

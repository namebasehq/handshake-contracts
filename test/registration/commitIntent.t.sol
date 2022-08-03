// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

import "interfaces/ICommitIntent.sol";
import "src/contracts/SldCommitIntent.sol";


contract SldCommitIntentTests is Test {


    ICommitIntent internal intent;

    function setUp() public {
     
        intent = new SldCommitIntent(address(this));
    }

    function testMissedCommitDeadline() public {

        //Arrange
        bytes32 node = bytes32(uint256(666));
        uint256 startBlock = 10;        
        uint256 maxBlocks = intent.MaxBlockWaitForCommit();
        bytes32 secret = bytes32(uint256(42424242));

        //Act
        vm.roll(startBlock);
        intent.commitIntent(node);
        vm.roll(startBlock + maxBlocks);

        //Assert
        bool allowed = intent.allowedCommit(node, secret, address(this));
        assertFalse(allowed);
    }


    function testBeatCommitDeadline() public {
        
        //Arrange
        bytes32 node = bytes32(uint256(667));
        bytes32 secret = bytes32(uint256(2432423));

        uint256 startBlock = 10;        
        uint256 maxBlocks = intent.MaxBlockWaitForCommit();

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
        uint256 startBlock = 10;        
        uint256 maxBlocks = intent.MaxBlockWaitForCommit();
        bytes32 secret = bytes32(uint256(420420));

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

        //Act
        vm.roll(startBlock);
        intent.commitIntent(node);
        
        vm.roll(startBlock + 2);

        //Assert
        vm.expectRevert("already been committed");
        intent.commitIntent(node);
        
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

}


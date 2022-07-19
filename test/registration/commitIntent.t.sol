// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

import "interfaces/registration/ICommitIntent.sol";
import "src/contracts/registration/SldCommitIntent.sol";


contract SldCommitIntentTests is Test {


    ICommitIntent internal intent;

    function setUp() public {
     
        intent = new SldCommitIntent();
    }

    function testMissedCommitDeadline() public {

        //Arrange
        bytes32 node = bytes32(uint256(666));
        uint256 startBlock = 10;        
        uint256 maxBlocks = intent.MaxBlockWaitForCommit();

        //Act
        vm.roll(startBlock);
        intent.commitIntent(node);
        vm.roll(startBlock + maxBlocks);

        //Assert
        bool allowed = intent.allowedCommit(node, address(this));
        assertFalse(allowed);
    }


    function testBeatCommitDeadline() public {
        
        //Arrange
        bytes32 node = bytes32(uint256(667));
        uint256 startBlock = 10;        
        uint256 maxBlocks = intent.MaxBlockWaitForCommit();

        //Act
        vm.roll(startBlock);
        intent.commitIntent(node);
        vm.roll(startBlock + maxBlocks - 1);

        //Assert
        bool allowed = intent.allowedCommit(node, address(this));
        assertTrue(allowed);
    }

    function testBeatCommitDeadlineCheckWithOtherAccount() public {
        
        //Arrange
        bytes32 node = bytes32(uint256(667));
        uint256 startBlock = 10;        
        uint256 maxBlocks = intent.MaxBlockWaitForCommit();

        //Act
        vm.roll(startBlock);
        intent.commitIntent(node);
        vm.roll(startBlock + maxBlocks - 1);

        //Assert

        bool allowed = intent.allowedCommit(node, address(0x1337));

        assertFalse(allowed);
    }

    function testBeatCommitDeadlineWithTwoNodes() public {
        
        //Arrange
        bytes32 node = bytes32(uint256(777));
        bytes32 node2 = bytes32(uint256(888));
        uint256 startBlock = 10;        
        uint256 maxBlocks = intent.MaxBlockWaitForCommit();

        //Act
        vm.roll(startBlock);
        intent.commitIntent(node);
        intent.commitIntent(node2);
        vm.roll(startBlock + maxBlocks - 1);

        //Assert
        bool allowed = intent.allowedCommit(node, address(this));
        bool allowed2 = intent.allowedCommit(node2, address(this));
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
        uint256 startBlock = 10;        
        uint256 maxBlocks = intent.MaxBlockWaitForCommit();

        //Act
        vm.roll(startBlock);
        intent.commitIntent(node);
        
        vm.roll(startBlock + maxBlocks + 1);
        bool allowed = intent.allowedCommit(node, address(this));

        //Assert
        assertFalse(allowed);
        address user = address(0x08);
        vm.prank(user);
        intent.commitIntent(node);
        bool allowed2 = intent.allowedCommit(node, user);
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


// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

import "interfaces/registration/ITldClaimManager.sol";
import "src/contracts/registration/TldClaimManager.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";


contract TldClaimManagerTests is Test {

    ITldClaimManager internal manager;




    function setUp() public {
        manager = new TldClaimManager();

    }

     function testClaimWithInvalidProofs() public {
        //Assign
        //we can use utils/merkle.js to generate proofs and merkle root for testing.
        bytes32 validMerkleRoot = 0x205212ad33543bbb5be9e371d2036c9422fb8a188f86f8a9e947f1af1890d8bb;
        address validWallet = 0x91769843CEc84Adcf7A48DF9DBd9694A39f44b42;

        bytes32 namehash = bytes32(uint256(0x01));
        bytes32[] memory validProofs = new bytes32[](3);
        
        validProofs[0] = 0x1e82fbae58d7ed9c05f505cc96c65e5a0c3c47470ef39959baccc90495344416;
        validProofs[1] = 0x653fc0e2eddd57a28e95b5cd17fc5167708d1800742234b83624cd9b3fc2f72e;
        //validProofs[2] = 0x376a026a4bf5ac47d4b25340041249ce790843ee4257be1ac7b0e52c8899162f;
        validProofs[2] = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

        //Act
        manager.setMerkleRoot(validMerkleRoot);        
        bool result = manager.canClaim(validWallet, namehash, validProofs);
        
        //Assert
        assertFalse(result);
     }

     function testClaimWithInvalidWallet() public {
        //Assign
        //we can use utils/merkle.js to generate proofs and merkle root for testing.
        bytes32 validMerkleRoot = 0x205212ad33543bbb5be9e371d2036c9422fb8a188f86f8a9e947f1af1890d8bb;
        address invalidWallet = address(0x69420);

        bytes32 namehash = bytes32(uint256(0x01));
        bytes32[] memory validProofs = new bytes32[](3);
        
        validProofs[0] = 0x1e82fbae58d7ed9c05f505cc96c65e5a0c3c47470ef39959baccc90495344416;
        validProofs[1] = 0x653fc0e2eddd57a28e95b5cd17fc5167708d1800742234b83624cd9b3fc2f72e;
        validProofs[2] = 0x376a026a4bf5ac47d4b25340041249ce790843ee4257be1ac7b0e52c8899162f;

        //Act
        manager.setMerkleRoot(validMerkleRoot);        
        bool result = manager.canClaim(invalidWallet, namehash, validProofs);
        
        //Assert
        assertFalse(result);
     }

     function testClaimWithCorrectProofs() public {
        
        //Assign
        //we can use utils/merkle.js to generate proofs and merkle root for testing.
        bytes32 validMerkleRoot = 0x205212ad33543bbb5be9e371d2036c9422fb8a188f86f8a9e947f1af1890d8bb;
        address validWallet = 0x91769843CEc84Adcf7A48DF9DBd9694A39f44b42;

        bytes32 namehash = bytes32(uint256(0x01));
        bytes32[] memory validProofs = new bytes32[](3);
        
        validProofs[0] = 0x1e82fbae58d7ed9c05f505cc96c65e5a0c3c47470ef39959baccc90495344416;
        validProofs[1] = 0x653fc0e2eddd57a28e95b5cd17fc5167708d1800742234b83624cd9b3fc2f72e;
        validProofs[2] = 0x376a026a4bf5ac47d4b25340041249ce790843ee4257be1ac7b0e52c8899162f;

        //Act
        manager.setMerkleRoot(validMerkleRoot);        
        bool result = manager.canClaim(validWallet, namehash, validProofs);
        
        //Assert
        assertTrue(result);
     }

     function testClaimWithTldThatDoesNotExist() public {

        //Assign
        //we can use utils/merkle.js to generate proofs and merkle root for testing.
        bytes32 validMerkleRoot = 0x205212ad33543bbb5be9e371d2036c9422fb8a188f86f8a9e947f1af1890d8bb;
        address validWallet = 0x91769843CEc84Adcf7A48DF9DBd9694A39f44b42;

        bytes32 namehash = bytes32(uint256(0x02));
        bytes32[] memory validProofs = new bytes32[](3);
        
        validProofs[0] = 0x1e82fbae58d7ed9c05f505cc96c65e5a0c3c47470ef39959baccc90495344416;
        validProofs[1] = 0x653fc0e2eddd57a28e95b5cd17fc5167708d1800742234b83624cd9b3fc2f72e;
        validProofs[2] = 0x376a026a4bf5ac47d4b25340041249ce790843ee4257be1ac7b0e52c8899162f;

        //Act
        manager.setMerkleRoot(validMerkleRoot);        
        bool result = manager.canClaim(validWallet, namehash, validProofs);
        
        //Assert
        assertFalse(result);

     }

     function testClaimWithMerkleRootNotSet() public {

        //Assign
        //we can use utils/merkle.js to generate proofs and merkle root for testing.
        address validWallet = 0x91769843CEc84Adcf7A48DF9DBd9694A39f44b42;

        bytes32 namehash = bytes32(uint256(0x01));
        bytes32[] memory validProofs = new bytes32[](3);
        
        validProofs[0] = 0x1e82fbae58d7ed9c05f505cc96c65e5a0c3c47470ef39959baccc90495344416;
        validProofs[1] = 0x653fc0e2eddd57a28e95b5cd17fc5167708d1800742234b83624cd9b3fc2f72e;
        validProofs[2] = 0x376a026a4bf5ac47d4b25340041249ce790843ee4257be1ac7b0e52c8899162f;

        //Act
        // don't set this on purpose  >> manager.setMerkleRoot(validMerkleRoot);        
        bool result = manager.canClaim(validWallet, namehash, validProofs);
        assertFalse(result);
     }

     function testOwnerCanUpdateMerkleRoot() public {
        bytes32 validMerkleRoot = bytes32(uint256(0x1337));
        manager.setMerkleRoot(validMerkleRoot);

        assertEq(manager.MerkleRoot(), validMerkleRoot);
     }

     function testUserCannotUpdateMerkleRoot() public {
        bytes32 validMerkleRoot = bytes32(uint256(0x1337));
        vm.startPrank(address(0x6666));
        vm.expectRevert("Ownable: caller is not the owner");
        manager.setMerkleRoot(validMerkleRoot);
        vm.stopPrank();
     }

     function testClaimWhenTldAlreadyClaimed() public {
        //Assign
        //we can use utils/merkle.js to generate proofs and merkle root for testing.
        bytes32 validMerkleRoot = 0x205212ad33543bbb5be9e371d2036c9422fb8a188f86f8a9e947f1af1890d8bb;
        address validWallet = 0x91769843CEc84Adcf7A48DF9DBd9694A39f44b42;

        bytes32 namehash = bytes32(uint256(0x01));
        bytes32[] memory validProofs = new bytes32[](3);
        
        validProofs[0] = 0x1e82fbae58d7ed9c05f505cc96c65e5a0c3c47470ef39959baccc90495344416;
        validProofs[1] = 0x653fc0e2eddd57a28e95b5cd17fc5167708d1800742234b83624cd9b3fc2f72e;
        validProofs[2] = 0x376a026a4bf5ac47d4b25340041249ce790843ee4257be1ac7b0e52c8899162f;

        //Act
        manager.setMerkleRoot(validMerkleRoot); 
        bool resultBefore = manager.canClaim(validWallet, namehash, validProofs);

        TldNft tld = new TldNft();
        tld.setTldClaimManager(manager);
        manager.setTldNftContract(tld);

        manager.claimTld(validWallet, namehash, validProofs);    
        bool resultAfter = manager.canClaim(validWallet, namehash, validProofs);
        
        //Assert
        assertTrue(resultBefore);
        assertFalse(resultAfter);
    
        vm.expectRevert("not eligible to claim");
        manager.claimTld(validWallet, namehash, validProofs); 
     }
}
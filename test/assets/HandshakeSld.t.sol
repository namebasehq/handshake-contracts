// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import "src/contracts/HandshakeSld.sol";
import "test/mocks/mockCommitIntent.sol";
import "test/mocks/mockLabelValidator.sol";
import "@openzeppelin/contracts/access/Ownable.sol";



contract HandshakeSldTests is Test {

    using stdStorage for StdStorage;
    HandshakeSld Sld;

    function setUp() public {
        Sld = new HandshakeSld();

        //this mock validator will always pass true
        MockLabelValidator validator = new MockLabelValidator(true);

        //update commit intent with mock object
        stdstore.target(address(Sld))
                .sig("LabelValidator()")
                .checked_write(address(validator));
    }

    function testUpdateLabelValidatorWithOwnerWalletExpectSuccess() public {
        MockLabelValidator validator = new MockLabelValidator(false);
        Sld.updateLabelValidator(validator);

        assertEq(address(Sld.LabelValidator()), address(validator));

    }

    function testUpdateLabelValidatorWithNotOwnerWalletExpectFail() public {
        
        //assign
        MockLabelValidator validator = new MockLabelValidator(false);
        address currentValidatorAddress = address(Sld.LabelValidator());
        address otherWallet = address(0x224466);

        //act
        vm.startPrank(otherWallet);
        vm.expectRevert("Ownable: caller is not the owner");
        Sld.updateLabelValidator(validator);

        //assert
        //should not have changed
        assertEq(currentValidatorAddress, address(Sld.LabelValidator()));
        vm.stopPrank();
    }


    function testOwnerOfTldContractSetCorrectly() public {

        assertEq(address(this), Ownable(address(Sld.HandshakeTldContract())).owner());
    }

    function testOwnerOfCommitIntentSetCorrectly() public {

        assertEq(address(this), Ownable(address(Sld.CommitIntent())).owner());
    }

    function testMintSldFromAuthorisedWallet() public {
        string memory label = "";
        bytes32 secret = bytes32(0x0);
        uint256 registrationLength = 50;
        bytes32 parentNamehash = bytes32(0x0);
        MockCommitIntent intent = new MockCommitIntent(true);

        //update commit intent with mock object
        stdstore.target(address(Sld))
                .sig("CommitIntent()")
                .checked_write(address(intent));

        address claimant = address(0x6666);
        
        vm.startPrank(claimant);
        Sld.purchaseSld(label, secret, registrationLength, parentNamehash);
        vm.stopPrank();

        assertEq(Sld.balanceOf(claimant), 1);
    }

    function testMintDuplicateSldFromAuthorisedWallet() public {
        string memory label = "";
        bytes32 secret = bytes32(0x0);
        uint256 registrationLength = 50;
        bytes32 parentNamehash = bytes32(0x0);
        MockCommitIntent intent = new MockCommitIntent(true);

        //update commit intent with mock object
        stdstore.target(address(Sld))
                .sig("CommitIntent()")
                .checked_write(address(intent));

        address claimant = address(0x6666);
        
        vm.startPrank(claimant);
        Sld.purchaseSld(label, secret, registrationLength, parentNamehash);
        vm.expectRevert("ALREADY_MINTED");
        Sld.purchaseSld(label, secret, registrationLength, parentNamehash);
        vm.stopPrank();

        assertEq(Sld.balanceOf(claimant), 1);
    }

    function testCheckParentNamehashIsCorrectAfterMint() public {
        string memory label = "testing";
        bytes32 secret = bytes32(0x0);
        uint256 registrationLength = 50;
        bytes32 parentNamehash = bytes32(uint256(0x1234567890abcdef));
        MockCommitIntent intent = new MockCommitIntent(true);

        //update commit intent with mock object
        stdstore.target(address(Sld))
                .sig("CommitIntent()")
                .checked_write(address(intent));

        address claimant = address(0x6666);
        
        vm.startPrank(claimant);
        Sld.purchaseSld(label, secret, registrationLength, parentNamehash);

        bytes32 full_hash = keccak256(abi.encodePacked(parentNamehash, keccak256(abi.encodePacked(label))));

        assertEq(parentNamehash, Sld.NamehashToParentMap(full_hash));
    }


    function testCheckLabelToNamehashIsCorrectAfterMint() public {
        string memory label = "testing";
        bytes32 secret = bytes32(0x0);
        uint256 registrationLength = 50;
        bytes32 parentNamehash = bytes32(uint256(0x1234567890abcdef));
        MockCommitIntent intent = new MockCommitIntent(true);

        //update commit intent with mock object
        stdstore.target(address(Sld))
                .sig("CommitIntent()")
                .checked_write(address(intent));

        address claimant = address(0x6666);
        
        vm.startPrank(claimant);
        Sld.purchaseSld(label, secret, registrationLength, parentNamehash);

        bytes32 full_hash = keccak256(abi.encodePacked(parentNamehash, keccak256(abi.encodePacked(label))));

        assertEq(label, Sld.NamehashToLabelMap(full_hash));
    }

}
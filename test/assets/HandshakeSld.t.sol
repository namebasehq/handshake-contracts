// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import "src/contracts/HandshakeSld.sol";
import "test/mocks/mockCommitIntent.sol";
import "test/mocks/mockLabelValidator.sol";
import "test/mocks/mockPriceStrategy.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract HandshakeSldTests is Test {
    using stdStorage for StdStorage;
    HandshakeSld Sld;

    function setUp() public {
        Sld = new HandshakeSld();
        addMockValidatorToSld();

    }

    function addMockValidatorToSld() private {
        //this mock validator will always pass true
        MockLabelValidator validator = new MockLabelValidator(true);

        //update commit intent with mock object
        stdstore.target(address(Sld)).sig("LabelValidator()").checked_write(
            address(validator)
        );
    }

    function addMockPriceStrategyToTld(bytes32 _tldNamehash) private {
        MockPriceStrategy strategy = new MockPriceStrategy();

        stdstore
            .target(address(Sld))
            .sig("SldDefaultPriceStrategy(bytes32)")
            .with_key(_tldNamehash)
            .checked_write(address(strategy));
    }

    function addMockCommitIntent(bool _returnValue) private {
        MockCommitIntent intent = new MockCommitIntent(_returnValue);

        //update commit intent with mock object
        stdstore.target(address(Sld)).sig("CommitIntent()").checked_write(
            address(intent)
        );
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

        addMockPriceStrategyToTld(parentNamehash);
        addMockCommitIntent(true);

        bytes32[] memory empty_array;
        address claimant = address(0x6666);

        vm.startPrank(claimant);
        Sld.purchaseSld(label, secret, registrationLength, parentNamehash, empty_array);
        vm.stopPrank();

        assertEq(Sld.balanceOf(claimant), 1);
    }

    function testMintDuplicateSldFromAuthorisedWallet() public {
        string memory label = "";
        bytes32 secret = bytes32(0x0);
        uint256 registrationLength = 50;
        bytes32 parentNamehash = bytes32(0x0);

        addMockPriceStrategyToTld(parentNamehash);
        addMockCommitIntent(true);

        address claimant = address(0x6666);
        bytes32[] memory empty_array;
        vm.startPrank(claimant);
        Sld.purchaseSld(label, secret, registrationLength, parentNamehash, empty_array);
        vm.expectRevert("ALREADY_MINTED");
        Sld.purchaseSld(label, secret, registrationLength, parentNamehash, empty_array);
        vm.stopPrank();

        assertEq(Sld.balanceOf(claimant), 1);
    }

    function testCheckParentNamehashIsCorrectAfterMint() public {
        string memory label = "testing";
        bytes32 secret = bytes32(0x0);
        uint256 registrationLength = 50;
        bytes32 parentNamehash = bytes32(uint256(0x1234567890abcdef));

        addMockPriceStrategyToTld(parentNamehash);
        addMockCommitIntent(true);

        address claimant = address(0x6666);

        bytes32[] memory empty_array;
        vm.startPrank(claimant);
        Sld.purchaseSld(label, secret, registrationLength, parentNamehash, empty_array);

        bytes32 full_hash = keccak256(
            abi.encodePacked(parentNamehash, keccak256(abi.encodePacked(label)))
        );

        assertEq(parentNamehash, Sld.NamehashToParentMap(uint256(full_hash)));
    }

    function testCheckLabelToNamehashIsCorrectAfterMint() public {
        string memory label = "testing";
        bytes32 secret = bytes32(0x0);
        uint256 registrationLength = 50;
        bytes32 parentNamehash = bytes32(uint256(0x1234567890abcdef));

        addMockPriceStrategyToTld(parentNamehash);
        addMockCommitIntent(true);

        address claimant = address(0x6666);
        bytes32[] memory empty_array;
        vm.startPrank(claimant);
        Sld.purchaseSld(label, secret, registrationLength, parentNamehash, empty_array);

        bytes32 full_hash = keccak256(
            abi.encodePacked(parentNamehash, keccak256(abi.encodePacked(label)))
        );

        assertEq(label, Sld.NamehashToLabelMap(full_hash));
    }

    function testSetRoyaltyPaymentAddressForTldFromTldOwnerAddress() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address payoutAddress = address(0x22886644);

        HandshakeTld tld = Sld.HandshakeTldContract();

        bytes32[] memory emptyArr;

        bytes32 parent_hash = bytes32(keccak256(abi.encodePacked(tldName)));

        addMockPriceStrategyToTld(parent_hash);
        addMockCommitIntent(true);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.mint(tldOwner, tldName);

        vm.prank(sldOwner);
        Sld.purchaseSld("test", bytes32(0x0), 50, parent_hash, emptyArr);

        //test.test
        uint256 expectedSldId = uint256(
            keccak256(
                abi.encodePacked(
                    keccak256(abi.encodePacked("test")),
                    keccak256(abi.encodePacked("test"))
                )
            )
        );

        assertEq(
            expectedSldId,
            37174255505552296075550689388107631271928910089020902890185083882243638892035
        );

        uint256 tldId = uint256(bytes32(keccak256(abi.encodePacked(tldName))));

        assertEq(tldId, uint256(parent_hash));

        vm.prank(tldOwner);
        Sld.setRoyaltyPayoutAddress(tldId, payoutAddress);
        (address _addr, ) = Sld.royaltyInfo(expectedSldId, 100);
        assertEq(_addr, payoutAddress);
        vm.stopPrank();
    }

    function testSetRoyaltyPaymentAddressForTldNotSet_ShouldReturnTldOwner() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address payoutAddress = address(0x22886644);

        HandshakeTld tld = Sld.HandshakeTldContract();

        bytes32[] memory emptyArr;

        bytes32 parent_hash = bytes32(keccak256(abi.encodePacked(tldName)));

        addMockPriceStrategyToTld(parent_hash);
        addMockCommitIntent(true);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.mint(tldOwner, tldName);

        vm.prank(sldOwner);
        Sld.purchaseSld("test", bytes32(0x0), 50, parent_hash, emptyArr);

        //test.test
        uint256 expectedSldId = uint256(
            keccak256(
                abi.encodePacked(
                    keccak256(abi.encodePacked("test")),
                    keccak256(abi.encodePacked("test"))
                )
            )
        );

        assertEq(
            expectedSldId,
            37174255505552296075550689388107631271928910089020902890185083882243638892035
        );

        uint256 tldId = uint256(bytes32(keccak256(abi.encodePacked(tldName))));

        assertEq(tldId, uint256(parent_hash));

        (address _addr, ) = Sld.royaltyInfo(expectedSldId, 100);
        assertEq(_addr, tldOwner);
        vm.stopPrank();
    }

    function testSetRoyaltyPaymentAddressThenTransferTld_AddressShouldResetToNewOwner()
        public
    {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address payoutAddress = address(0x22886644);

        HandshakeTld tld = Sld.HandshakeTldContract();

        bytes32[] memory emptyArr;

        bytes32 parent_hash = bytes32(keccak256(abi.encodePacked(tldName)));

        addMockPriceStrategyToTld(parent_hash);
        addMockCommitIntent(true);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.mint(tldOwner, tldName);

        vm.prank(sldOwner);
        Sld.purchaseSld("test", bytes32(0x0), 50, parent_hash, emptyArr);

        //test.test
        uint256 expectedSldId = uint256(
            keccak256(
                abi.encodePacked(
                    keccak256(abi.encodePacked("test")),
                    keccak256(abi.encodePacked("test"))
                )
            )
        );

        assertEq(
            expectedSldId,
            37174255505552296075550689388107631271928910089020902890185083882243638892035
        );

        uint256 tldId = uint256(bytes32(keccak256(abi.encodePacked(tldName))));

        assertEq(tldId, uint256(parent_hash));

        vm.startPrank(tldOwner);
        Sld.setRoyaltyPayoutAddress(tldId, payoutAddress);
        (address _addr, ) = Sld.royaltyInfo(expectedSldId, 100);
        assertEq(_addr, payoutAddress);

        address newOwner = address(0x66);

        Sld.HandshakeTldContract().safeTransferFrom(tldOwner, newOwner, tldId);
        (address _addr2, ) = Sld.royaltyInfo(expectedSldId, 100);
        assertEq(_addr2, newOwner);

        vm.stopPrank();
    }

    function testSetRoyaltyPaymentAddressForTldFromTldOwnerApprovedAddress() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address payoutAddress = address(0x22886644);

        HandshakeTld tld = Sld.HandshakeTldContract();

        bytes32[] memory emptyArr;

        bytes32 parent_hash = bytes32(keccak256(abi.encodePacked(tldName)));

        addMockPriceStrategyToTld(parent_hash);
        addMockCommitIntent(true);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.mint(tldOwner, tldName);

        vm.prank(sldOwner);
        Sld.purchaseSld("test", bytes32(0x0), 50, parent_hash, emptyArr);

        //test.test
        uint256 expectedSldId = uint256(
            keccak256(
                abi.encodePacked(
                    keccak256(abi.encodePacked("test")),
                    keccak256(abi.encodePacked("test"))
                )
            )
        );

        assertEq(
            expectedSldId,
            37174255505552296075550689388107631271928910089020902890185083882243638892035
        );

        uint256 tldId = uint256(bytes32(keccak256(abi.encodePacked(tldName))));

        assertEq(tldId, uint256(parent_hash));

        address approvedAddress = address(0x2299);

        vm.startPrank(tldOwner); //need to start/stop prank as this is a chained call
        Sld.HandshakeTldContract().setApprovalForAll(approvedAddress, true);
        vm.stopPrank();

        vm.prank(approvedAddress);
        Sld.setRoyaltyPayoutAddress(tldId, payoutAddress);
        (address _addr, ) = Sld.royaltyInfo(expectedSldId, 100);
        assertEq(_addr, payoutAddress);
        vm.stopPrank();
    }

    function testSetRoyaltyPaymentAddressForTldFromNotTldOwnerAddress_ExpectFail()
        public
    {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address payoutAddress = address(0x22886644);

        HandshakeTld tld = Sld.HandshakeTldContract();

        bytes32[] memory emptyArr;

        bytes32 parent_hash = bytes32(keccak256(abi.encodePacked(tldName)));

        addMockPriceStrategyToTld(parent_hash);
        addMockCommitIntent(true);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.mint(tldOwner, tldName);

        vm.prank(sldOwner);
        Sld.purchaseSld("test", bytes32(0x0), 50, parent_hash, emptyArr);

        //test.test
        uint256 expectedSldId = uint256(
            keccak256(
                abi.encodePacked(
                    keccak256(abi.encodePacked("test")),
                    keccak256(abi.encodePacked("test"))
                )
            )
        );

        assertEq(
            expectedSldId,
            37174255505552296075550689388107631271928910089020902890185083882243638892035
        );

        uint256 tldId = uint256(bytes32(keccak256(abi.encodePacked(tldName))));

        assertEq(tldId, uint256(parent_hash));

        address notApprovedAddress = address(0x2299);

        vm.prank(notApprovedAddress);
        vm.expectRevert("not approved or owner of parent domain");
        Sld.setRoyaltyPayoutAddress(tldId, payoutAddress);
    }

    function testSetRoyaltyPaymentAmountForTldFromTldOwnerAddress() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address payoutAddress = address(0x22886644);

        HandshakeTld tld = Sld.HandshakeTldContract();

        bytes32[] memory emptyArr;

        bytes32 parent_hash = bytes32(keccak256(abi.encodePacked(tldName)));

        addMockPriceStrategyToTld(parent_hash);
        addMockCommitIntent(true);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.mint(tldOwner, tldName);

        vm.prank(sldOwner);
        Sld.purchaseSld("test", bytes32(0x0), 50, parent_hash, emptyArr);

        //test.test
        uint256 expectedSldId = uint256(
            keccak256(
                abi.encodePacked(
                    keccak256(abi.encodePacked("test")),
                    keccak256(abi.encodePacked("test"))
                )
            )
        );

        assertEq(
            expectedSldId,
            37174255505552296075550689388107631271928910089020902890185083882243638892035
        );

        uint256 tldId = uint256(bytes32(keccak256(abi.encodePacked(tldName))));

        assertEq(tldId, uint256(parent_hash));

        uint256 expectedRoyaltyAmount = 1;
        uint256 setRoyaltyNumber = 10;

        vm.prank(tldOwner);
        Sld.setRoyaltyPayoutAmount(tldId, setRoyaltyNumber);
        (, uint256 royaltyAmount) = Sld.royaltyInfo(expectedSldId, 100);
        assertEq(royaltyAmount, expectedRoyaltyAmount);
        vm.stopPrank();
    }

    function testRoyaltyPaymentAmountNotSetForTldFromTldOwnerAddress() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address payoutAddress = address(0x22886644);

        HandshakeTld tld = Sld.HandshakeTldContract();

        bytes32[] memory emptyArr;

        bytes32 parent_hash = bytes32(keccak256(abi.encodePacked(tldName)));

        addMockPriceStrategyToTld(parent_hash);
        addMockCommitIntent(true);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.mint(tldOwner, tldName);

        vm.prank(sldOwner);
        Sld.purchaseSld("test", bytes32(0x0), 50, parent_hash, emptyArr);

        //test.test
        uint256 expectedSldId = uint256(
            keccak256(
                abi.encodePacked(
                    keccak256(abi.encodePacked("test")),
                    keccak256(abi.encodePacked("test"))
                )
            )
        );

        assertEq(
            expectedSldId,
            37174255505552296075550689388107631271928910089020902890185083882243638892035
        );

        uint256 tldId = uint256(bytes32(keccak256(abi.encodePacked(tldName))));

        assertEq(tldId, uint256(parent_hash));

        uint256 expectedRoyaltyAmount = 0;

        (, uint256 royaltyAmount) = Sld.royaltyInfo(expectedSldId, 100);
        assertEq(royaltyAmount, expectedRoyaltyAmount);
        vm.stopPrank();
    }

    function testSetRoyaltyPaymentAmountForTldFromTldOwnerApprovedAddress() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address payoutAddress = address(0x22886644);

        HandshakeTld tld = Sld.HandshakeTldContract();

        bytes32[] memory emptyArr;

        bytes32 parent_hash = bytes32(keccak256(abi.encodePacked(tldName)));

        addMockPriceStrategyToTld(parent_hash);
        addMockCommitIntent(true);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.mint(tldOwner, tldName);

        vm.prank(sldOwner);
        Sld.purchaseSld("test", bytes32(0x0), 50, parent_hash, emptyArr);

        //test.test
        uint256 expectedSldId = uint256(
            keccak256(
                abi.encodePacked(
                    keccak256(abi.encodePacked("test")),
                    keccak256(abi.encodePacked("test"))
                )
            )
        );

        assertEq(
            expectedSldId,
            37174255505552296075550689388107631271928910089020902890185083882243638892035
        );

        uint256 tldId = uint256(bytes32(keccak256(abi.encodePacked(tldName))));

        assertEq(tldId, uint256(parent_hash));

        address approvedAddress = address(0x2299);

        vm.startPrank(tldOwner); //need to start/stop prank as this is a chained call
        Sld.HandshakeTldContract().setApprovalForAll(approvedAddress, true);
        vm.stopPrank();

        uint256 expectedRoyaltyAmount = 1;
        uint256 setRoyaltyNumber = 10;

        vm.prank(approvedAddress);
        Sld.setRoyaltyPayoutAmount(tldId, setRoyaltyNumber);
        (, uint256 royaltyAmount) = Sld.royaltyInfo(expectedSldId, 100);
        assertEq(royaltyAmount, expectedRoyaltyAmount);
    }

    function testSetRoyaltyPaymentAmountForTldFromNotTldOwnerAddress_ExpectFail() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address payoutAddress = address(0x22886644);

        HandshakeTld tld = Sld.HandshakeTldContract();

        bytes32[] memory emptyArr;

        bytes32 parent_hash = bytes32(keccak256(abi.encodePacked(tldName)));

        addMockPriceStrategyToTld(parent_hash);
        addMockCommitIntent(true);

        //we can just spoof the claim manager address using cheatcode to pass authorisation
        tld.setTldClaimManager(ITldClaimManager(tldOwner));

        vm.prank(tldOwner);
        tld.mint(tldOwner, tldName);

        vm.prank(sldOwner);
        Sld.purchaseSld("test", bytes32(0x0), 50, parent_hash, emptyArr);

        //test.test
        uint256 expectedSldId = uint256(
            keccak256(
                abi.encodePacked(
                    keccak256(abi.encodePacked("test")),
                    keccak256(abi.encodePacked("test"))
                )
            )
        );

        assertEq(
            expectedSldId,
            37174255505552296075550689388107631271928910089020902890185083882243638892035
        );

        uint256 tldId = uint256(bytes32(keccak256(abi.encodePacked(tldName))));

        assertEq(tldId, uint256(parent_hash));

        address notApprovedAddress = address(0x2299);

        uint256 expectedRoyaltyAmount = 1;
        uint256 setRoyaltyNumber = 10;

        vm.prank(notApprovedAddress);
        vm.expectRevert("not approved or owner of parent domain");
        Sld.setRoyaltyPayoutAmount(tldId, setRoyaltyNumber);
    }

    function testSetRoyaltyPaymentAddressForSldParentFromSldParentOwnerAddress() public {}

    function testSetRoyaltyPaymentAddressForSldParentNotSet_ShouldReturnSldParentOwner()
        public
    {}

    function testSetRoyaltyPaymentAddressThenTransferSldParentNft_AddressShouldResetToNewOwner()
        public
    {}

    function testSetRoyaltyPaymentAddressForSldParentFromSldParentOwnerApprovedAddress()
        public
    {}

    function testSetRoyaltyPaymentAddressForSldParentFromNotSldParentOwnerAddress_ExpectFail()
        public
    {}

    function testSetRoyaltyPaymentAmountForSldParentFromSldParentOwnerAddress() public {}

    function testSetRoyaltyPaymentAmountForSldParentFromSldParentOwnerApprovedAddress()
        public
    {}

    function testSetRoyaltyPaymentAmountForSldParentFromNotSldParentOwnerAddress_ExpectFail()
        public
    {}
}

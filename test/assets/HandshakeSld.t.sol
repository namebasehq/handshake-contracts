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
    error MissingPriceStrategy();

    using stdStorage for StdStorage;
    HandshakeSld Sld;

    function setUp() public {
        Sld = new HandshakeSld();
        addMockValidatorToSld();
    }

    function getNamehash(string memory _label, bytes32 _parentHash)
        private
        pure
        returns (bytes32)
    {
        bytes32 encoded_label = keccak256(abi.encodePacked(_label));
        bytes32 big_hash = keccak256(abi.encodePacked(_parentHash, encoded_label));

        return big_hash;
    }

    function addMockValidatorToSld() private {
        //this mock validator will always pass true
        MockLabelValidator validator = new MockLabelValidator(true);

        //update commit intent with mock object
        stdstore.target(address(Sld)).sig("LabelValidator()").checked_write(
            address(validator)
        );
    }

    function addMockPriceStrategyToTld(bytes32 _tldNamehash, uint256 _price) private {
        MockPriceStrategy strategy = new MockPriceStrategy(_price);

        stdstore
            .target(address(Sld))
            .sig("SldDefaultPriceStrategy(bytes32)")
            .with_key(_tldNamehash)
            .checked_write(address(strategy));
    }

    function addMockPriceStrategyToTld(bytes32 _tldNamehash) private {
        addMockPriceStrategyToTld(_tldNamehash, 0);
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

    function testOwnerOfChildContractsSetCorrectly() public {
        //this is the deployer of the contract!!
        address myAddress = address(0xbeef);

        vm.prank(myAddress);
        HandshakeSld tempSld = new HandshakeSld();

        assertEq(Ownable(tempSld.HandshakeTldContract()).owner(), myAddress);
        assertEq(
            Ownable(address(tempSld.HandshakeTldContract().ClaimManager())).owner(),
            myAddress
        );
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

    function testMintSldFromAuthorisedWalletWithMissingPriceStrategy() public {
        string memory label = "";
        bytes32 secret = bytes32(0x0);
        uint256 registrationLength = 50;
        bytes32 parentNamehash = bytes32(0x0);

        //comment out for the test.
        //addMockPriceStrategyToTld(parentNamehash);
        addMockCommitIntent(true);

        bytes32[] memory empty_array;
        address claimant = address(0x6666);

        vm.startPrank(claimant);
        vm.expectRevert(MissingPriceStrategy.selector);
        Sld.purchaseSld(label, secret, registrationLength, parentNamehash, empty_array);
        vm.stopPrank();

        assertEq(Sld.balanceOf(claimant), 0);
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

    function testMultiPurchaseSldWithIncorrectArrayLengths_expectFail() public {
        string[] memory label = new string[](3);
        bytes32[] memory secret = new bytes32[](3);
        uint256[] memory registrationLength = new uint256[](3);
        bytes32[] memory parentNamehash = new bytes32[](3);
        bytes32[][] memory proofs = new bytes32[][](3);
        address[] memory receiver = new address[](2);

        vm.expectRevert("all arrays should be the same length");
        Sld.purchaseMultipleSld(
            label,
            secret,
            registrationLength,
            parentNamehash,
            proofs,
            receiver
        );
    }

    function testMultiPurchaseSldWithIncorrectArrayLengths_expectFail_2() public {
        string[] memory label = new string[](2);
        bytes32[] memory secret = new bytes32[](3);
        uint256[] memory registrationLength = new uint256[](3);
        bytes32[] memory parentNamehash = new bytes32[](3);
        bytes32[][] memory proofs = new bytes32[][](3);
        address[] memory receiver = new address[](3);

        vm.expectRevert("all arrays should be the same length");
        Sld.purchaseMultipleSld(
            label,
            secret,
            registrationLength,
            parentNamehash,
            proofs,
            receiver
        );
    }

    function testMultiPurchaseSld() public {
        string[] memory label = new string[](2);
        bytes32[] memory secret = new bytes32[](2);
        uint256[] memory registrationLength = new uint256[](2);
        bytes32[] memory parentNamehash = new bytes32[](2);

        label[0] = "test1";
        label[1] = "test2";

        secret[0] = bytes32(abi.encodePacked(uint256(0x0)));
        secret[1] = bytes32(abi.encodePacked(uint256(0x1)));

        registrationLength[0] = 50;
        registrationLength[1] = 100;

        parentNamehash[0] = bytes32(abi.encodePacked(uint256(0x2)));
        parentNamehash[1] = bytes32(abi.encodePacked(uint256(0x3)));

        addMockPriceStrategyToTld(parentNamehash[0]);
        addMockPriceStrategyToTld(parentNamehash[1]);
        addMockCommitIntent(true);

        bytes32[][] memory empty_array = new bytes32[][](2);

        address claimant = address(0x6666);
        address[] memory receiver = new address[](2);

        receiver[0] = address(0x0123);
        receiver[1] = address(0x2345);

        vm.startPrank(claimant);
        Sld.purchaseMultipleSld(
            label,
            secret,
            registrationLength,
            parentNamehash,
            empty_array,
            receiver
        );
        vm.stopPrank();

        assertEq(Sld.balanceOf(receiver[0]), 1);
        assertEq(Sld.balanceOf(receiver[1]), 1);
        assertEq(Sld.balanceOf(claimant), 0);
    }

    function testMultiPurchaseSldWithZeroAddressInReceiver() public {
        string[] memory label = new string[](2);
        bytes32[] memory secret = new bytes32[](2);
        uint256[] memory registrationLength = new uint256[](2);
        bytes32[] memory parentNamehash = new bytes32[](2);

        label[0] = "test1";
        label[1] = "test2";

        secret[0] = bytes32(abi.encodePacked(uint256(0x0)));
        secret[1] = bytes32(abi.encodePacked(uint256(0x1)));

        registrationLength[0] = 50;
        registrationLength[1] = 100;

        parentNamehash[0] = bytes32(abi.encodePacked(uint256(0x2)));
        parentNamehash[1] = bytes32(abi.encodePacked(uint256(0x3)));

        addMockPriceStrategyToTld(parentNamehash[0]);
        addMockPriceStrategyToTld(parentNamehash[1]);
        addMockCommitIntent(true);

        bytes32[][] memory empty_array = new bytes32[][](2);

        address claimant = address(0x6666);
        address[] memory receiver = new address[](2);

        receiver[0] = address(0x0123);

        //comment this guy out for the test
        //receiver[1] = address(0x2345);

        vm.startPrank(claimant);
        Sld.purchaseMultipleSld(
            label,
            secret,
            registrationLength,
            parentNamehash,
            empty_array,
            receiver
        );
        vm.stopPrank();

        assertEq(Sld.balanceOf(receiver[0]), 1);
        assertEq(Sld.balanceOf(claimant), 1);
    }

    function testPurchaseSldToZeroAddress_expectSendToMsgSender() public {
        string memory label = "testit";
        bytes32 secret = bytes32(0x0);
        uint256 registrationLength = 50;
        bytes32 parentNamehash = bytes32(0x0);

        addMockPriceStrategyToTld(parentNamehash);
        addMockCommitIntent(true);

        bytes32[] memory empty_array;
        address claimant = address(0x6666);

        vm.startPrank(claimant);

        Sld.purchaseSld(
            label,
            secret,
            registrationLength,
            parentNamehash,
            empty_array,
            address(0)
        );
        vm.stopPrank();

        assertEq(Sld.balanceOf(claimant), 1);
    }

    function testPurchaseSldToOtherAddress() public {
        string memory label = "testit";
        bytes32 secret = bytes32(0x0);
        uint256 registrationLength = 50;
        bytes32 parentNamehash = bytes32(0x0);

        addMockPriceStrategyToTld(parentNamehash);
        addMockCommitIntent(true);

        bytes32[] memory empty_array;
        address claimant = address(0x6666);
        address receiver = address(0x8888);

        vm.startPrank(claimant);
        Sld.purchaseSld(
            label,
            secret,
            registrationLength,
            parentNamehash,
            empty_array,
            receiver
        );
        vm.stopPrank();

        assertEq(Sld.balanceOf(receiver), 1);
        assertEq(Sld.balanceOf(claimant), 0);
    }

    function testMultiPurchaseSldToOtherAddressWithMissingPriceStrategy_expectFail()
        public
    {
        string[] memory label = new string[](2);
        bytes32[] memory secret = new bytes32[](2);
        uint256[] memory registrationLength = new uint256[](2);
        bytes32[] memory parentNamehash = new bytes32[](2);

        label[0] = "test1";
        label[1] = "test2";

        secret[0] = bytes32(abi.encodePacked(uint256(0x0)));
        secret[1] = bytes32(abi.encodePacked(uint256(0x1)));

        registrationLength[0] = 50;
        registrationLength[1] = 100;

        parentNamehash[0] = bytes32(abi.encodePacked(uint256(0x2)));
        parentNamehash[1] = bytes32(abi.encodePacked(uint256(0x3)));

        addMockPriceStrategyToTld(parentNamehash[0]);

        //commented this out for the test
        //addMockPriceStrategyToTld(parentNamehash[1]);
        addMockCommitIntent(true);

        bytes32[][] memory empty_array = new bytes32[][](2);

        address claimant = address(0x6666);
        address[] memory receiver = new address[](2);

        receiver[0] = address(0x0123);
        receiver[1] = address(0x2345);

        vm.startPrank(claimant);
        vm.expectRevert(MissingPriceStrategy.selector);
        Sld.purchaseMultipleSld(
            label,
            secret,
            registrationLength,
            parentNamehash,
            empty_array,
            receiver
        );
        vm.stopPrank();
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

        uint256 expectedRoyaltyAmount = 90;
        uint256 setRoyaltyNumber = 3;

        vm.prank(tldOwner);
        Sld.setRoyaltyPayoutAmount(tldId, setRoyaltyNumber);
        (, uint256 royaltyAmount) = Sld.royaltyInfo(expectedSldId, 3000);
        assertEq(royaltyAmount, expectedRoyaltyAmount);
        vm.stopPrank();
    }

    function testSetRoyaltyPaymentAmountForTldFromTldOwnerAddressOver10Percent_expectFail()
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

        uint256 tldId = uint256(bytes32(keccak256(abi.encodePacked(tldName))));

        uint256 setRoyaltyNumber = 11;

        vm.startPrank(tldOwner);

        //not expecting fail from this one
        Sld.setRoyaltyPayoutAmount(tldId, 10);

        vm.expectRevert("10% maximum royalty on SLD");
        Sld.setRoyaltyPayoutAmount(tldId, setRoyaltyNumber);
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
        uint256 setRoyaltyNumber = 1;

        vm.prank(approvedAddress);
        Sld.setRoyaltyPayoutAmount(tldId, setRoyaltyNumber);
        emit log_named_uint("royalty amount set", Sld.RoyaltyPayoutAmountMap(tldId));
        (, uint256 royaltyAmount) = Sld.royaltyInfo(expectedSldId, 100);
        assertEq(royaltyAmount, expectedRoyaltyAmount);
    }

    function testAddPriceStrategyToTldDomain_pass() public {
        string memory label = "";
        bytes32 secret = bytes32(0x0);
        uint256 registrationLength = 50;

        uint256 id = 70622639689279718371527342103894932928233838121221666359043189029713682937432;
        bytes32 parentNamehash = bytes32(id);
        addMockCommitIntent(true);

        string memory domain = "test";
        address parent_address = address(0x12345678);
        stdstore
            .target(address(Sld.HandshakeTldContract()))
            .sig("ClaimManager()")
            .checked_write(parent_address);

        vm.startPrank(parent_address);
        Sld.HandshakeTldContract().mint(parent_address, domain);

        address strat = address(new MockPriceStrategy(1));
        Sld.setPricingStrategy(parentNamehash, strat);

        assertEq(address(Sld.getPricingStrategy(parentNamehash)), strat);
    }

    function testAddPriceStrategyToSldDomain_pass() public {
        string memory label = "";
        bytes32 secret = bytes32(0x0);
        uint256 registrationLength = 50;

        uint256 id = 70622639689279718371527342103894932928233838121221666359043189029713682937432;
        bytes32 parentNamehash = bytes32(id);
        addMockCommitIntent(true);

        string memory domain = "test";
        address parent_address = address(0x12345678);
        address child_address = address(0x22446688);
        stdstore
            .target(address(Sld.HandshakeTldContract()))
            .sig("ClaimManager()")
            .checked_write(parent_address);

        vm.startPrank(parent_address);
        Sld.HandshakeTldContract().mint(parent_address, domain);

        address strat = address(new MockPriceStrategy(0));
        Sld.setPricingStrategy(parentNamehash, strat);

        assertEq(address(Sld.getPricingStrategy(parentNamehash)), strat);
        vm.stopPrank();

        vm.startPrank(child_address);

        bytes32[] memory emptyArr;

        bytes32 namehash = getNamehash("test", parentNamehash);

        Sld.purchaseSld(
            "test",
            bytes32(uint256(0x0)),
            666,
            parentNamehash,
            emptyArr,
            child_address
        );
        address childStrat = address(new MockPriceStrategy(1));
        Sld.setPricingStrategy(namehash, childStrat);

        assertEq(address(Sld.getPricingStrategy(namehash)), childStrat);
        vm.stopPrank();
    }

    function testAddPriceStrategyToSldNotOwner_fail() public {
        string memory label = "";
        bytes32 secret = bytes32(0x0);
        uint256 registrationLength = 50;

        uint256 id = 70622639689279718371527342103894932928233838121221666359043189029713682937432;
        bytes32 parentNamehash = bytes32(id);
        addMockCommitIntent(true);

        string memory domain = "test";
        address parent_address = address(0x12345678);
        address child_address = address(0x22446688);
        stdstore
            .target(address(Sld.HandshakeTldContract()))
            .sig("ClaimManager()")
            .checked_write(parent_address);

        vm.startPrank(parent_address);
        Sld.HandshakeTldContract().mint(parent_address, domain);

        address strat = address(new MockPriceStrategy(0));
        Sld.setPricingStrategy(parentNamehash, strat);

        assertEq(address(Sld.getPricingStrategy(parentNamehash)), strat);
        vm.stopPrank();

        vm.startPrank(child_address);

        bytes32[] memory emptyArr;

        bytes32 namehash = getNamehash("test", parentNamehash);

        //we mint to other address 0x1337
        Sld.purchaseSld(
            "test",
            bytes32(uint256(0x0)),
            666,
            parentNamehash,
            emptyArr,
            address(0x1337)
        );
        address childStrat = address(new MockPriceStrategy(1));
        vm.expectRevert("not approved or owner of parent domain");
        Sld.setPricingStrategy(namehash, childStrat);

        vm.stopPrank();
    }

    function testAddPriceStrategyToTldNotOwner_fail() public {
        string memory label = "";
        bytes32 secret = bytes32(0x0);
        uint256 registrationLength = 50;

        uint256 id = 70622639689279718371527342103894932928233838121221666359043189029713682937432;
        bytes32 parentNamehash = bytes32(id);
        addMockCommitIntent(true);

        string memory domain = "test";
        address parent_address = address(0x12345678);
        address not_parent_address = address(0x222222);
        stdstore
            .target(address(Sld.HandshakeTldContract()))
            .sig("ClaimManager()")
            .checked_write(parent_address);

        vm.startPrank(parent_address);
        Sld.HandshakeTldContract().mint(parent_address, domain);
        vm.stopPrank();

        vm.startPrank(not_parent_address);
        address strat = address(new MockPriceStrategy(1));
        vm.expectRevert("not approved or owner of parent domain");
        Sld.setPricingStrategy(parentNamehash, strat);
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

    function testSetRoyaltyPaymentAddressForSldChildFromSldOwnerAddress() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address sldSldOwner = address(0xababab);
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

        bytes32 sldHash = keccak256(
            abi.encodePacked(
                keccak256(abi.encodePacked("test")),
                keccak256(abi.encodePacked("test"))
            )
        );

        uint256 sldId = uint256(sldHash);

        //test.test.test
        uint256 expectedSldChildId = uint256(getNamehash(string("test"), sldHash));

        addMockPriceStrategyToTld(sldHash);

        vm.prank(sldSldOwner);
        Sld.purchaseSld("test", bytes32(0x0), 50, sldHash, emptyArr);

        assertEq(
            Sld.ownerOf(
                88982020594716641930034915809615336174528308807841887087431718240342441944320
            ),
            sldSldOwner,
            "no owner of child of SLD"
        );

        assertEq(
            expectedSldChildId,
            88982020594716641930034915809615336174528308807841887087431718240342441944320,
            "id for child of sld does not return correctly."
        );

        uint256 tldId = uint256(bytes32(keccak256(abi.encodePacked(tldName))));

        assertEq(tldId, uint256(parent_hash));

        address notApprovedAddress = address(0x2299);

        uint256 expectedRoyaltyAmount = 4;
        uint256 setRoyaltyNumber = 2;

        vm.prank(sldOwner);
        Sld.setRoyaltyPayoutAmount(sldId, setRoyaltyNumber);

        (, uint256 royaltyAmount) = Sld.royaltyInfo(expectedSldChildId, 200);
        assertEq(royaltyAmount, expectedRoyaltyAmount);
    }

    function testSetSldRoyaltyPaymentAddressForSldChildFromTldOwnerAddress_expectFail()
        public
    {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address sldSldOwner = address(0xababab);
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

        bytes32 sldHash = keccak256(
            abi.encodePacked(
                keccak256(abi.encodePacked("test")),
                keccak256(abi.encodePacked("test"))
            )
        );

        uint256 sldId = uint256(sldHash);

        //test.test.test
        uint256 expectedSldChildId = uint256(getNamehash(string("test"), sldHash));

        addMockPriceStrategyToTld(sldHash);

        vm.prank(sldSldOwner);
        Sld.purchaseSld("test", bytes32(0x0), 50, sldHash, emptyArr);

        assertEq(
            Sld.ownerOf(
                88982020594716641930034915809615336174528308807841887087431718240342441944320
            ),
            sldSldOwner,
            "no owner of child of SLD"
        );

        assertEq(
            expectedSldChildId,
            88982020594716641930034915809615336174528308807841887087431718240342441944320,
            "id for child of sld does not return correctly."
        );

        uint256 tldId = uint256(bytes32(keccak256(abi.encodePacked(tldName))));

        assertEq(tldId, uint256(parent_hash));

        uint256 expectedRoyaltyAmount = 1;
        uint256 setRoyaltyNumber = 10;

        vm.prank(tldOwner);
        vm.expectRevert("not approved or owner of parent domain");
        Sld.setRoyaltyPayoutAmount(sldId, setRoyaltyNumber);
    }

    function testSetRoyaltyPaymentAddressForSldParentNotSet_ShouldReturnSldParentOwner()
        public
    {}

    function testSetRoyaltyPaymentAddressForSldChildrenFromSldOwner() public {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address sldSldOwner = address(0xababab);
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

        assertEq(
            Sld.ownerOf(
                37174255505552296075550689388107631271928910089020902890185083882243638892035
            ),
            sldOwner,
            "SLD owner not correct"
        );

        bytes32 sldHash = keccak256(
            abi.encodePacked(
                keccak256(abi.encodePacked("test")),
                keccak256(abi.encodePacked("test"))
            )
        );

        uint256 sldId = uint256(sldHash);

        //test.test.test
        uint256 expectedSldChildId = uint256(getNamehash(string("test"), sldHash));

        addMockPriceStrategyToTld(sldHash);

        vm.prank(sldSldOwner);
        Sld.purchaseSld("test", bytes32(0x0), 50, sldHash, emptyArr);

        assertEq(
            Sld.ownerOf(
                88982020594716641930034915809615336174528308807841887087431718240342441944320
            ),
            sldSldOwner,
            "no owner of child of SLD"
        );

        assertEq(
            expectedSldChildId,
            88982020594716641930034915809615336174528308807841887087431718240342441944320,
            "id for child of sld does not return correctly."
        );

        uint256 tldId = uint256(bytes32(keccak256(abi.encodePacked(tldName))));

        assertEq(tldId, uint256(parent_hash));

        bytes32 parentNamehash = Sld.NamehashToParentMap(sldId);
        uint256 parentId = uint256(parentNamehash);

        emit log_named_uint("parent id is :", parentId);
        emit log_named_uint("expected parent id is :", tldId);

        vm.startPrank(sldOwner);
        Sld.setRoyaltyPayoutAddress(sldId, payoutAddress);

        (address _addr, ) = Sld.royaltyInfo(expectedSldChildId, 100);
        assertEq(_addr, payoutAddress);
        vm.stopPrank();
    }

    function testSetRoyaltyPaymentAddressThenTransferSldParentNft_AddressShouldResetToNewOwner()
        public
    {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address sldSldOwner = address(0xababab);
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

        bytes32 sldHash = keccak256(
            abi.encodePacked(
                keccak256(abi.encodePacked("test")),
                keccak256(abi.encodePacked("test"))
            )
        );

        uint256 sldId = uint256(sldHash);

        //test.test.test
        uint256 expectedSldChildId = uint256(getNamehash(string("test"), sldHash));

        addMockPriceStrategyToTld(sldHash);

        vm.prank(sldSldOwner);
        Sld.purchaseSld("test", bytes32(0x0), 50, sldHash, emptyArr);

        uint256 tldId = uint256(bytes32(keccak256(abi.encodePacked(tldName))));

        assertEq(tldId, uint256(parent_hash));

        bytes32 parentNamehash = Sld.NamehashToParentMap(sldId);
        uint256 parentId = uint256(parentNamehash);

        address newOwnerAddress = address(0xbada55);

        vm.startPrank(sldOwner);
        Sld.setRoyaltyPayoutAddress(sldId, payoutAddress);
        Sld.safeTransferFrom(sldOwner, newOwnerAddress, sldId);

        (address _addr, ) = Sld.royaltyInfo(expectedSldChildId, 100);

        //this should change to the new owner address
        assertEq(_addr, newOwnerAddress);
        vm.stopPrank();
    }

    function testSetRoyaltyPaymentAmountForSldParentFromSldParentOwnerApprovedAddress()
        public
    {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address sldSldOwner = address(0xababab);
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

        bytes32 sldHash = keccak256(
            abi.encodePacked(
                keccak256(abi.encodePacked("test")),
                keccak256(abi.encodePacked("test"))
            )
        );

        uint256 sldId = uint256(sldHash);

        //test.test.test
        uint256 expectedSldChildId = uint256(getNamehash(string("test"), sldHash));

        addMockPriceStrategyToTld(sldHash);

        vm.prank(sldSldOwner);
        Sld.purchaseSld("test", bytes32(0x0), 50, sldHash, emptyArr);

        uint256 tldId = uint256(bytes32(keccak256(abi.encodePacked(tldName))));

        assertEq(tldId, uint256(parent_hash));

        bytes32 parentNamehash = Sld.NamehashToParentMap(sldId);
        uint256 parentId = uint256(parentNamehash);

        address approvedAddress = address(0xbada55);

        vm.prank(sldOwner);
        Sld.setApprovalForAll(approvedAddress, true);

        uint256 payoutAmount = 10;

        vm.startPrank(approvedAddress);
        Sld.setRoyaltyPayoutAmount(sldId, payoutAmount);

        assertEq(
            Sld.ownerOf(expectedSldChildId),
            sldSldOwner,
            "invalid child of SLD owner"
        );

        emit log_named_uint("royalty amount", Sld.RoyaltyPayoutAmountMap(sldId));
        (, uint256 amount) = Sld.royaltyInfo(expectedSldChildId, 100);

        //this should change to the new owner address
        assertEq(amount, 10);
        vm.stopPrank();
    }

    function testSetRoyaltyPaymentAmountForSldParentFromNotSldParentOwnerAddress_ExpectFail()
        public
    {
        string memory tldName = "test";
        address tldOwner = address(0x44668822);
        address sldOwner = address(0x232323);
        address sldSldOwner = address(0xababab);
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

        bytes32 sldHash = keccak256(
            abi.encodePacked(
                keccak256(abi.encodePacked("test")),
                keccak256(abi.encodePacked("test"))
            )
        );

        uint256 sldId = uint256(sldHash);

        //test.test.test
        uint256 expectedSldChildId = uint256(getNamehash(string("test"), sldHash));

        addMockPriceStrategyToTld(sldHash);

        vm.prank(sldSldOwner);
        Sld.purchaseSld("test", bytes32(0x0), 50, sldHash, emptyArr);

        uint256 tldId = uint256(bytes32(keccak256(abi.encodePacked(tldName))));

        assertEq(tldId, uint256(parent_hash));

        bytes32 parentNamehash = Sld.NamehashToParentMap(sldId);
        uint256 parentId = uint256(parentNamehash);

        address notApprovedAddress = address(0xbada55);

        uint256 payoutAmount = 10;

        vm.startPrank(notApprovedAddress);
        vm.expectRevert("not approved or owner of parent domain");
        Sld.setRoyaltyPayoutAmount(sldId, payoutAmount);
        vm.stopPrank();
    }

    function testGetSubdomainDetailsValidationCheckShouldPassIfArrayLengthsAllTheSame(
        uint8 _arrayLength
    ) public {
        address[] memory recipients = new address[](_arrayLength);
        uint256[] memory parentIds = new uint256[](_arrayLength);
        string[] memory labels = new string[](_arrayLength);
        uint256[] memory registrationLengths = new uint256[](_arrayLength);
        bytes32[][] memory proofs = new bytes32[][](_arrayLength);

        addMockPriceStrategyToTld(bytes32(0x0), 0);
        Sld.getSubdomainDetails(
            recipients,
            parentIds,
            labels,
            registrationLengths,
            proofs
        );
    }

    function testGetSubdomainDetailsValidationCheckShouldFailIfArrayLengthsParentIdsDifferent()
        public
    {
        address[] memory recipients = new address[](5);
        uint256[] memory parentIds = new uint256[](6);
        string[] memory labels = new string[](5);
        uint256[] memory registrationLengths = new uint256[](5);
        bytes32[][] memory proofs = new bytes32[][](5);

        vm.expectRevert("array lengths are different");
        Sld.getSubdomainDetails(
            recipients,
            parentIds,
            labels,
            registrationLengths,
            proofs
        );
    }

    function testGetSubdomainDetailsValidationCheckShouldFailIfArrayLengthsLabelsDifferent()
        public
    {
        address[] memory recipients = new address[](5);
        uint256[] memory parentIds = new uint256[](5);
        string[] memory labels = new string[](4);
        uint256[] memory registrationLengths = new uint256[](5);
        bytes32[][] memory proofs = new bytes32[][](5);

        vm.expectRevert("array lengths are different");
        Sld.getSubdomainDetails(
            recipients,
            parentIds,
            labels,
            registrationLengths,
            proofs
        );
    }

    function testGetSubdomainDetailsValidationCheckShouldFailIfArrayLengthsRegistrationLengthsDifferent()
        public
    {
        address[] memory recipients = new address[](5);
        uint256[] memory parentIds = new uint256[](5);
        string[] memory labels = new string[](5);
        uint256[] memory registrationLengths = new uint256[](7);
        bytes32[][] memory proofs = new bytes32[][](5);

        vm.expectRevert("array lengths are different");
        Sld.getSubdomainDetails(
            recipients,
            parentIds,
            labels,
            registrationLengths,
            proofs
        );
    }

    function testGetSubdomainDetailsValidationCheckShouldFailIfArrayLengthsProofsDifferent()
        public
    {
        address[] memory recipients = new address[](5);
        uint256[] memory parentIds = new uint256[](5);
        string[] memory labels = new string[](5);
        uint256[] memory registrationLengths = new uint256[](5);
        bytes32[][] memory proofs = new bytes32[][](4);

        vm.expectRevert("array lengths are different");
        Sld.getSubdomainDetails(
            recipients,
            parentIds,
            labels,
            registrationLengths,
            proofs
        );
    }

    function testGetSubdomainDetailsValidationCheckShouldFailIfArrayLengthsRecipientsDifferent()
        public
    {
        address[] memory recipients = new address[](5);
        uint256[] memory parentIds = new uint256[](5);
        string[] memory labels = new string[](5);
        uint256[] memory registrationLengths = new uint256[](5);
        bytes32[][] memory proofs = new bytes32[][](4);

        vm.expectRevert("array lengths are different");
        Sld.getSubdomainDetails(
            recipients,
            parentIds,
            labels,
            registrationLengths,
            proofs
        );
    }

    function testGetSubdomainDetails_single(uint256 _price) public {
        address[] memory recipients = new address[](1);
        uint256[] memory parentIds = new uint256[](1);
        string[] memory labels = new string[](1);
        uint256[] memory registrationLengths = new uint256[](1);
        bytes32[][] memory proofs = new bytes32[][](1);
        bytes32[] memory empty_array;

        string memory label = "test";
        bytes32 secret = bytes32(0x0);
        uint256 registrationLength = 50;
        bytes32 parentNamehash = bytes32(uint256(0x121212));
        address recipient = address(0x998822);

        recipients[0] = recipient;
        parentIds[0] = uint256(parentNamehash);
        labels[0] = label;
        registrationLengths[0] = registrationLength;
        proofs[0] = empty_array;

        addMockPriceStrategyToTld(parentNamehash, _price);
        addMockCommitIntent(true);

        address claimant = address(0x6666);

        SubdomainDetail[] memory dets = Sld.getSubdomainDetails(
            recipients,
            parentIds,
            labels,
            registrationLengths,
            proofs
        );

        assertEq(dets.length, 1, "invalid array length");
        assertEq(dets[0].Price, _price, "mismatch in price");
        assertEq(
            dets[0].Id,
            uint256(getNamehash(labels[0], parentNamehash)),
            "expected Id does not match"
        );
        assertEq(dets[0].ParentId, parentIds[0], "Parent Id does not match");
        assertEq(dets[0].Label, labels[0], "subdomain label does not match");

        assertEq(dets[0].RoyaltyAmount, 0, "royalty amount does not match");
    }

    function testGetSubdomainDetails_multiple() public {
        uint256 _price = 69420;
        address[] memory recipients = new address[](3);
        uint256[] memory parentIds = new uint256[](3);
        string[] memory labels = new string[](3);
        uint256[] memory registrationLengths = new uint256[](3);
        bytes32[][] memory proofs = new bytes32[][](3);
        bytes32[] memory empty_array;

        string memory label = "test";
        bytes32 secret = bytes32(0x0);
        uint256 registrationLength = 50;
        bytes32 parentNamehash = bytes32(uint256(0x121212));
        address recipient = address(0x998822);

        recipients[0] = recipient;
        recipients[1] = recipient;
        recipients[2] = recipient;

        parentIds[0] = uint256(parentNamehash);
        parentIds[1] = uint256(parentNamehash);
        parentIds[2] = uint256(parentNamehash);

        labels[0] = label;
        labels[1] = label;
        labels[2] = label;

        registrationLengths[0] = registrationLength;
        registrationLengths[1] = registrationLength;
        registrationLengths[2] = registrationLength;

        proofs[0] = empty_array;
        proofs[1] = empty_array;
        proofs[2] = empty_array;

        addMockPriceStrategyToTld(parentNamehash, _price);
        addMockCommitIntent(true);

        SubdomainDetail[] memory dets = Sld.getSubdomainDetails(
            recipients,
            parentIds,
            labels,
            registrationLengths,
            proofs
        );

        //no worry about gas optimisation in the tests.
        for (uint256 i; i < dets.length; i++) {
            assertEq(dets.length, recipients.length, "invalid array length");
            assertEq(dets[i].Price, _price, "mismatch in price");
            assertEq(
                dets[i].Id,
                uint256(getNamehash(labels[i], parentNamehash)),
                "expected Id does not match"
            );
            assertEq(dets[i].ParentId, parentIds[i], "Parent Id does not match");
            assertEq(dets[i].Label, labels[i], "subdomain label does not match");

            //royalty amount not currently set in this test.
            // so should be zero
            assertEq(dets[i].RoyaltyAmount, 0, "royalty amount does not match");
        }
    }

    function testUpdatePriceStrategyFromSldOwner() public {
        string memory label = "testing123";
        bytes32 secret = bytes32(0x0);
        uint256 registrationLength = 50;
        bytes32 parentNamehash = bytes32(uint256(0x123456));

        MockPriceStrategy priceStrategy = new MockPriceStrategy(10);

        addMockPriceStrategyToTld(parentNamehash);
        addMockCommitIntent(true);

        bytes32[] memory empty_array;
        address claimant = address(0x6666);

        vm.startPrank(claimant);
        Sld.purchaseSld(label, secret, registrationLength, parentNamehash, empty_array);

        bytes32 childHash = getNamehash(label, parentNamehash);
        Sld.setPricingStrategy(childHash, address(priceStrategy));
        vm.stopPrank();
    }

    function testUpdatePriceStrategyFromNotSldOwner() public {
        string memory label = "testing123";
        bytes32 secret = bytes32(0x0);
        uint256 registrationLength = 50;
        bytes32 parentNamehash = bytes32(uint256(0x123456));

        MockPriceStrategy priceStrategy = new MockPriceStrategy(10);

        addMockPriceStrategyToTld(parentNamehash);
        addMockCommitIntent(true);

        bytes32[] memory empty_array;
        address claimant = address(0x6666);

        vm.prank(claimant);
        Sld.purchaseSld(label, secret, registrationLength, parentNamehash, empty_array);
        vm.startPrank(address(0x22446666));
        bytes32 childHash = getNamehash(label, parentNamehash);
        vm.expectRevert("not approved or owner of parent domain");
        Sld.setPricingStrategy(childHash, address(priceStrategy));
        vm.stopPrank();
    }
}

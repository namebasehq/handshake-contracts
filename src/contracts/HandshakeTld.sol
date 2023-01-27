// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Namehash} from "utils/Namehash.sol";
import "contracts/HandshakeNft.sol";
import "interfaces/IHandshakeTld.sol";

contract HandshakeTld is HandshakeNft, IHandshakeTld {
    ITldClaimManager public claimManager;

    // a map of string labels
    mapping(bytes32 => string) public namehashToLabelMap;
    mapping(bytes32 => ISldRegistrationStrategy) public registrationStrategy;

    address public claimManagerAddress;
    address public royaltyPayoutAddress;
    uint256 public royaltyPayoutAmount = 50; //default 5%

    constructor(ITldClaimManager _claimManager) HandshakeNft("TLD", "Top Level Domain") {
        claimManager = _claimManager;
    }

    function setTldClaimManager(ITldClaimManager _manager) public onlyOwner {
        claimManager = _manager;
    }

    function setRoyaltyPayoutAddress(address _addr) public onlyOwner {
        require(_addr != address(0), "cannot set to zero address");
        royaltyPayoutAddress = _addr;
    }

    function setRoyaltyPayoutAmount(uint256 _amount) public onlyOwner {
        require(_amount < 101, "10% maximum royalty on TLD");
        royaltyPayoutAmount = _amount;
    }

    function setRoyaltyPayoutAmountAndAddress(address _addr, uint256 _amount) public onlyOwner {
        require(_amount < 101, "10% maximum royalty on TLD");
        require(_addr != address(0), "cannot set to zero address");

        royaltyPayoutAddress = _addr;
        royaltyPayoutAmount = _amount;
    }

    function registerWithResolver(
        address _addr,
        string calldata _domain,
        ISldRegistrationStrategy _strategy
    ) external {
        require(address(claimManager) == msg.sender, "not authorised");
        bytes32 namehash = Namehash.getTldNamehash(_domain);

        _mint(_addr, uint256(namehash));
        namehashToLabelMap[namehash] = _domain;
        tokenResolverMap[namehash] = defaultResolver;
        registrationStrategy[namehash] = _strategy;
    }

    function setResolver(bytes32 _namehash, IResolver _resolver)
        public
        override(IHandshakeTld, HandshakeNft)
    {
        HandshakeNft.setResolver(_namehash, _resolver);
    }

    function name(bytes32 _namehash) public view override returns (string memory _name) {
        _name = namehashToLabelMap[_namehash];
    }

    /**
     * @notice Set the registration strategy for a TLD
     * @dev This function sets the registration strategy of a top level domain. Must be
     *      set by the owner of the top level domain
     * @param _namehash namehash of the top level domain
     * @param _strategy Linked registration strategy to the top level domain. It should
     *                  implement ISldRegistrationStrategy interface
     */
    function setRegistrationStrategy(bytes32 _namehash, ISldRegistrationStrategy _strategy)
        public
        onlyApprovedOrOwner(uint256(_namehash))
    {
        registrationStrategy[_namehash] = _strategy;
    }

    /**
     * Returns information about the royalty payouts for the contract
     *
     * @param salePrice The price of the item being sold
     * @return receiver The address to receive the royalty payment and the amount to be paid
     * @return royaltyAmount The amount of the royalty payment
     *
     * Implements the on-chain royalty payment standard defined in EIP-2981
     */
    function royaltyInfo(uint256, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        uint256 divisor = royaltyPayoutAmount / 10;
        uint256 amount = royaltyPayoutAmount == 0 || divisor == 0 ? 0 : salePrice / divisor;

        address payoutAddress = royaltyPayoutAddress == address(0) ? owner() : royaltyPayoutAddress;
        return (payoutAddress, amount);
    }

    function ownerOf(uint256 _id)
        public
        view
        override(HandshakeNft, IHandshakeTld)
        returns (address)
    {
        return HandshakeNft.ownerOf(_id);
    }

    function isApprovedOrOwner(address _operator, uint256 _id)
        public
        view
        override(HandshakeNft, IHandshakeTld)
        returns (bool)
    {
        return _isApprovedOrOwner(_operator, _id);
    }
}

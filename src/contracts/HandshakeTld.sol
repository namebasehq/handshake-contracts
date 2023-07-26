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

    address public royaltyPayoutAddress;
    uint256 public royaltyPayoutAmount = 50; //default 5%

    event RegistrationStrategySet(bytes32 indexed namehash, ISldRegistrationStrategy strategy);

    constructor() HandshakeNft("TLD", "Handshake TLD") {}

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

    /**
     * @dev Method to burn a token by ID.
     * Only callable by the TLD claim manager.
     * @notice This functionality not implemented in the claim manager
     * contract yet. But will likely be a 2 step auth that requires signed
     * message from a namebase wallet and also the burn transaction to be
     * initiated by the token owner.
     * @param _tokenId The ID of the token to be burned.
     */
    function burnTld(uint256 _tokenId) external isClaimManager {
        super._burn(_tokenId);
    }

    /**
     * @dev Method to register a domain with a resolver.
     * Only callable by the TldClaimManager contract.
     * If the namehash has expired, it will be burned and a new token will be minted.
     * The resolver is then set to the default resolver.
     *
     * @param _addr The address that will be assigned the new token.
     * @param _domain The domain being registered.
     * @param _strategy The registration strategy being employed.
     */
    function registerWithResolver(
        address _addr,
        string calldata _domain,
        ISldRegistrationStrategy _strategy
    ) external isClaimManager {
        bytes32 namehash = Namehash.getTldNamehash(_domain);

        if (hasExpired(namehash)) {
            _burn(uint256(namehash));
        }

        _mint(_addr, uint256(namehash));
        namehashToLabelMap[namehash] = _domain;

        registrationStrategy[namehash] = _strategy;
        emit RegistrationStrategySet(namehash, _strategy);

        tokenResolverMap[namehash] = defaultResolver;
        emit ResolverSet(namehash, address(defaultResolver));
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

    function expiry(bytes32 _namehash) public view override returns (uint256 _expiry) {
        return claimManager.tldExpiry(_namehash);
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
        emit RegistrationStrategySet(_namehash, _strategy);
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

    /**
     * @notice Check the owner of a specified token.
     * @dev This function returns back the owner of an NFT. Return back the contract owner if the TLD has expired
     * @param _tokenId The token ID of the SLD NFT to be checked
     * @return _addr Owner of NFT
     */
    function ownerOf(uint256 _tokenId)
        public
        view
        override(HandshakeNft, IHandshakeTld)
        returns (address _addr)
    {
        uint256 tldExpiry = expiry(bytes32(_tokenId));
        require(tldExpiry > 0, "Query for non-existent token");

        if (hasExpired(bytes32(_tokenId), tldExpiry)) {
            return owner();
        }

        return HandshakeNft.ownerOf(_tokenId);
    }

    function hasExpired(bytes32 _namehash) internal view override returns (bool) {
        uint256 tldExpiry = expiry(_namehash);
        return hasExpired(_namehash, tldExpiry);
    }

    function hasExpired(bytes32 _namehash, uint256 _expiry) private view returns (bool) {
        if (!_exists(uint256(_namehash))) {
            return false;
        }
        return uint256(block.timestamp) > _expiry;
    }

    function isApprovedOrOwner(address _operator, uint256 _id)
        public
        view
        override(HandshakeNft, IHandshakeTld)
        returns (bool)
    {
        return _isApprovedOrOwner(_operator, _id);
    }

    modifier isClaimManager() {
        require(address(claimManager) == msg.sender, "not authorised");
        _;
    }
}

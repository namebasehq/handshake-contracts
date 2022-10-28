// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "contracts/HandshakeNft.sol";
import "contracts/HandshakeTld.sol";
import "contracts/SldCommitIntent.sol";
import "interfaces/ICommitIntent.sol";
import "interfaces/IHandshakeSld.sol";
import "interfaces/IHandshakeTld.sol";
import "interfaces/ISldRegistrationStrategy.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "structs/SubdomainDetail.sol";
import "structs/SubdomainRegistrationDetail.sol";
import "interfaces/IPriceOracle.sol";
import "contracts/UsdPriceOracle.sol";
import "contracts/HasUsdOracle.sol";
import "interfaces/IGlobalRegistrationRules.sol";
import "contracts/PaymentManager.sol";
import "interfaces/ISldRegistrationManager.sol";

import {console} from "forge-std/console.sol";

/**
 * @title Decentralised subdomain NFTs
 * @author Sam Ward
 * @notice erc721 subdomain contract
 */
contract HandshakeSld is HandshakeNft, IHandshakeSld {
    // a map of string labels
    mapping(bytes32 => string) public namehashToLabelMap;
    mapping(bytes32 => uint256) public royaltyPayoutAmountMap;
    mapping(bytes32 => mapping(address => address)) public royaltyPayoutAddressMap;
    mapping(bytes32 => bytes32) public namehashToParentMap;
    mapping(bytes32 => ISldRegistrationStrategy) public registrationStrategy;

    IHandshakeTld public handshakeTldContract;

    IGlobalRegistrationRules public contractRegistrationStrategy;
    ISldRegistrationManager public registrationManager;

    error MissingRegistrationStrategy();

    constructor(IHandshakeTld _tld) HandshakeNft("SLD", "Handshake SLD") {
        handshakeTldContract = _tld;
    }

    /**
     * @notice Register and mint SLD NFT
     * @dev This function can only be called by the
     *      registration manager contract
     * @param _to The address that the SLD will be minted to.
     *            Zero address will be minted to msg.sender
     * @param _tldNamehash The bytes32 representation of the TLD
     * @param _label The label of the subdomain
     */
    function registerSld(
        address _to,
        bytes32 _tldNamehash,
        string calldata _label
    ) external isRegistrationManager {
        bytes32 sldNamehash = Namehash.getNamehash(_tldNamehash, _label);
        if (hasExpired(sldNamehash)) {
            _burn(uint256(sldNamehash));
        }
        _mint(_to, uint256(sldNamehash));
        namehashToParentMap[sldNamehash] = _tldNamehash;
        namehashToLabelMap[sldNamehash] = _label;
    }

    /**
     * @notice Register and mint SLD NFT
     * @dev This function is custom owner/approved checking function.
     * @param _operator The address that is being checked
     * @param _tokenId The token ID of the subdomain NFT to be checked
     * @return _allowed Is the address the owner or on the accepted list
     */
    function isApprovedOrOwner(address _operator, uint256 _tokenId)
        public
        view
        override(HandshakeNft, IHandshakeSld)
        returns (bool _allowed)
    {
        _allowed = HandshakeNft.isApprovedOrOwner(_operator, _tokenId);
    }

    /**
     * @notice Check the owner of a specified token.
     * @dev This function returns back the owner of an NFT. Will revert if the token does
     *      not exist or has expired.
     * @param _tokenId The token ID of the subdomain NFT to be checked
     * @return _addr Owner of NFT
     */
    function ownerOf(uint256 _tokenId)
        public
        view
        override(HandshakeNft, IHandshakeSld)
        returns (address _addr)
    {
        require(!hasExpired(bytes32(_tokenId)), "sld expired");
        _addr = HandshakeNft.ownerOf(_tokenId);
    }

    function hasExpired(bytes32 _sldNamehash) private view returns (bool _hasExpired) {
        (uint80 regTime, uint96 regLength, ) = registrationManager.subdomainRegistrationHistory(
            _sldNamehash
        );
        _hasExpired = regTime + regLength <= block.timestamp;
    }

    /**
     * @notice Get the registration strategy for a TLD
     * @dev This function gets the registration strategy of a top level domain. Will revert if
     *      the strategy is not set.
     * @param _parentNamehash Bytes32 representation of the top level domain
     * @return _strategy Linked registration strategy to the top level domain
     */
    function getRegistrationStrategy(bytes32 _parentNamehash)
        public
        view
        returns (ISldRegistrationStrategy _strategy)
    {
        _strategy = registrationStrategy[_parentNamehash];
        require(address(_strategy) != address(0), "registration strategy not set");
    }

    /**
     * @notice Set the registration strategy for a TLD
     * @dev This function sets the registration strategy of a top level domain. Must be
     *      set by the owner of the top level domain
     * @param _tldId uint256 representation of the top level domain
     * @param _strategy Linked registration strategy to the top level domain. It should
     *                  implement ISldRegistrationStrategy interface
     */
    function setRegistrationStrategy(uint256 _tldId, ISldRegistrationStrategy _strategy)
        public
        onlyParentApprovedOrOwner(_tldId)
    {
        registrationStrategy[bytes32(_tldId)] = _strategy;
    }

    function setRegistrationManager(ISldRegistrationManager _registrationManager) public onlyOwner {
        registrationManager = _registrationManager;
    }

    /**
     * @notice Set the % royalty amount
     * @dev This function sets the royalty percentage for EIP-2981 function. This
     *      function can only be run by the owner of the top level domain.
     * @param _id uint256 representation of the top level domain
     * @param _amount Percentage to be set. Should be between 1-10%.
     */
    function setRoyaltyPayoutAmount(uint256 _id, uint256 _amount)
        public
        onlyParentApprovedOrOwner(_id)
    {
        require(_amount <= 10, "10% maximum royalty on SLD");
        royaltyPayoutAmountMap[bytes32(_id)] = _amount;
    }

    /**
     * @notice Set the royalty payout address. This defaults to the owner of the
     *         top level domain in the first instance.
     * @dev This function sets the royalty payout wallet for EIP-2981 function. This
     *      function can only be run by the owner of the top level domain.
     * @param _id uint256 representation of the top level domain
     * @param _addr Address to be set for the on-chain royalties to be sent to.
     */
    function setRoyaltyPayoutAddress(uint256 _id, address _addr)
        public
        onlyParentApprovedOrOwner(_id)
    {
        require(_addr != address(0), "cannot set to zero address");
        royaltyPayoutAddressMap[bytes32(_id)][handshakeTldContract.ownerOf(_id)] = _addr;
    }

    function getSingleSubdomainDetails(
        address _recipient,
        uint256 _parentId,
        string calldata _label,
        uint256 _registrationLength
    ) private view returns (SubdomainDetail memory) {
        bytes32 parentHash = bytes32(_parentId);
        //will revert if pricing strategy does not exist.
        ISldRegistrationStrategy priceStrat = getRegistrationStrategy(parentHash);

        uint256 priceInDollars = priceStrat.getPriceInDollars(
            _recipient,
            parentHash,
            _label,
            _registrationLength
        );

        uint256 royaltyAmount = royaltyPayoutAmountMap[parentHash];

        SubdomainDetail memory detail = SubdomainDetail(
            uint256(Namehash.getNamehash(parentHash, _label)),
            _parentId,
            _label,
            priceInDollars,
            royaltyAmount
        );
        return detail;
    }

    /**
     * @notice Get multiple subdomain details, which includes the price and NFT details
     * @dev Input arrays should all be the same length.
     * @param _recipients Array of the recipients. Generally will just be the same address.
     * @param _parentIds Array of the parent IDs
     * @param _labels Array of the subdomain labels to be queried.
     * @param _registrationLengths Array of the length of registration (days)
     * @return _details
     */
    function getSubdomainDetails(
        address[] calldata _recipients,
        uint256[] calldata _parentIds,
        string[] calldata _labels,
        uint256[] calldata _registrationLengths
    ) external view returns (SubdomainDetail[] memory _details) {
        uint256 len = _parentIds.length;
        require(
            (len ^ _recipients.length ^ _labels.length ^ _registrationLengths.length) == 0,
            "array lengths are different"
        );

        _details = new SubdomainDetail[](len);

        for (uint256 i; i < len; ) {
            _details[i] = getSingleSubdomainDetails(
                _recipients[i],
                _parentIds[i],
                _labels[i],
                _registrationLengths[i]
            );

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Gets the fully qualified domain name including TLD
     * @dev This function will get the full domain name sld.tld.
     *      It will revert if the domain does not exist.
     * @param _sldNamehash bytes32 representation of the sub domain
     * @return _fullDomain
     */
    function name(bytes32 _sldNamehash) external view override returns (string memory _fullDomain) {
        bytes32 tldNamehash = namehashToParentMap[_sldNamehash];
        require(tldNamehash != 0x0, "domain does not exist");
        string memory tldLabel = handshakeTldContract.namehashToLabelMap(tldNamehash);
        string memory sldLabel = namehashToLabelMap[_sldNamehash];

        _fullDomain = string(abi.encodePacked(sldLabel, ".", tldLabel));
    }

    function parent(bytes32 _sldNamehash)
        external
        view
        override
        returns (string memory _parentName)
    {
        bytes32 tldNamehash = namehashToParentMap[_sldNamehash];
        require(tldNamehash != 0x0, "domain does not exist");

        _parentName = handshakeTldContract.namehashToLabelMap(tldNamehash);
    }

    function expiry(bytes32 _namehash) external view override returns (uint256 _expiry) {
        (uint80 regTime, uint96 regLength, ) = registrationManager.subdomainRegistrationHistory(
            _namehash
        );

        _expiry = regTime + regLength;
    }

    /**
     * @notice Gets the royalty information for a subdomain
     * @dev This function will get EIP-2981 royalty information based on the TLD
     * @param tokenId uint256 representation of the sub domain
     * @param salePrice this does not link to any specific currency
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        bytes32 parentNamehash = namehashToParentMap[bytes32(tokenId)];
        uint256 parentId = uint256(parentNamehash);

        address owner = handshakeTldContract.ownerOf(parentId);

        receiver = royaltyPayoutAddressMap[parentNamehash][owner] == address(0)
            ? owner
            : royaltyPayoutAddressMap[parentNamehash][owner];

        royaltyAmount = royaltyPayoutAmountMap[parentNamehash] == 0
            ? 0
            : ((salePrice / 100) * royaltyPayoutAmountMap[parentNamehash]);
    }

    modifier onlyParentApprovedOrOwner(uint256 _id) {
        require(handshakeTldContract.isApprovedOrOwner(msg.sender, _id), "not authorised");
        _;
    }

    modifier isRegistrationManager() {
        require(address(registrationManager) == msg.sender, "not authorised");
        _;
    }
}

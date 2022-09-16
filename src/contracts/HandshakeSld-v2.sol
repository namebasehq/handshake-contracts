// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

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

import {console} from "forge-std/console.sol";

contract HandshakeSld_v2 is HandshakeNft, HasUsdOracle, PaymentManager, IHandshakeSld {
    using ERC165Checker for address;

    mapping(bytes32 => uint256) public royaltyPayoutAmountMap;
    mapping(bytes32 => mapping(address => address)) public royaltyPayoutAddressMap;
    mapping(bytes32 => bytes32) public namehashToParentMap;
    mapping(bytes32 => ISldRegistrationStrategy) public sldDefaultRegistrationStrategy;

    ICommitIntent public commitIntent;

    IHandshakeTld handshakeTldContract;

    IGlobalRegistrationRules public contractRegistrationStrategy;

    uint256 private DECIMAL_MULTIPLIER = 1000;

    error MissingRegistrationStrategy();

    //interface method for price strategy
    bytes4 private constant PRICE_IN_DOLLARS_SELECTOR =
        bytes4(keccak256("getPriceInDollars(address,bytes32,string,uint256)"));

    constructor(IHandshakeTld _tld, ICommitIntent _commitIntent)
        HandshakeNft("SLD", "Handshake SLD")
        PaymentManager(msg.sender)
    {
        commitIntent = _commitIntent;
        handshakeTldContract = _tld;
    }

    function registerSld(address _to, bytes32 _tldNamehash, bytes32 _sldNamehash) external {

    }

     function isApprovedOrOwner(address spender, uint256 tokenId) public view override(HandshakeNft, IHandshakeSld) returns (bool){
        return HandshakeNft.isApprovedOrOwner(spender, tokenId);
     }

    function getRegistrationStrategy(bytes32 _parentNamehash)
        public
        view
        returns (ISldRegistrationStrategy)
    {
        ISldRegistrationStrategy strategy = sldDefaultRegistrationStrategy[_parentNamehash];
        if (address(strategy) == address(0))
        {
            revert MissingRegistrationStrategy();
        }

        return strategy;

    }

    function setRegistrationStrategy(uint256 _id, address _strategy)
        public
        onlyParentApprovedOrOwner(_id)
    {
        require(
            _strategy.supportsInterface(PRICE_IN_DOLLARS_SELECTOR),
            "missing interface for price strategy"
        );
        sldDefaultRegistrationStrategy[bytes32(_id)] = ISldRegistrationStrategy(_strategy);
    }

    function setRoyaltyPayoutAmount(uint256 _id, uint256 _amount)
        public
        onlyParentApprovedOrOwner(_id)
    {
        require(_amount <= 10, "10% maximum royalty on SLD");
        royaltyPayoutAmountMap[bytes32(_id)] = _amount;
    }

    function setRoyaltyPayoutAddress(uint256 _id, address _addr)
        public
        onlyParentApprovedOrOwner(_id)
    {
        require(_addr != address(0), "cannot set to zero address");
        address parentOwner = exists(_id) ? ownerOf(_id) : handshakeTldContract.ownerOf(_id);
        royaltyPayoutAddressMap[bytes32(_id)][parentOwner] = _addr;
    }

    function getSingleSubdomainDetails(
        address _recipient,
        uint256 _parentId,
        string calldata _label,
        uint256 _registrationLength,
        bytes32[] calldata _proofs
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
            uint256(getNamehash(parentHash, _label)),
            _parentId,
            _label,
            priceInDollars,
            royaltyAmount
        );

        return detail;
    }

    function getSubdomainDetails(
        address[] calldata _recipients,
        uint256[] calldata _parentIds,
        string[] calldata _labels,
        uint256[] calldata _registrationLengths,
        bytes32[][] calldata _proofs
    ) external view returns (SubdomainDetail[] memory) {
        uint256 len = _parentIds.length;
        require(
            (len ^ _recipients.length ^ _labels.length ^ _proofs.length) == 0 &&
                len == _proofs.length &&
                len == _registrationLengths.length,
            "array lengths are different"
        );

        SubdomainDetail[] memory arr = new SubdomainDetail[](len);

        for (uint256 i; i < len; ) {
            bytes32[] memory empty_arr;
            arr[i] = getSingleSubdomainDetails(
                _recipients[i],
                _parentIds[i],
                _labels[i],
                _registrationLengths[i],
                _proofs[i]
            );

            unchecked {
                ++i;
            }
        }

        return arr;
    }

    function setHandshakeWalletAddress(address _addr) public onlyOwner {
        require(_addr != address(0), "cannot set to zero address");
        handshakeWalletPayoutAddress = _addr;
    }

    function setPriceOracle(IPriceOracle _oracle) public onlyOwner {
        usdOracle = _oracle;
        emit NewUsdOracle(address(_oracle));
    }

    function setGlobalRegistrationStrategy(address _strategy) public onlyOwner {
        require(
            _strategy.supportsInterface(type(IGlobalRegistrationRules).interfaceId),
            "IGlobalRegistrationRules interface not supported"
        );

        contractRegistrationStrategy = IGlobalRegistrationRules(_strategy);
    }

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
        require(
            handshakeTldContract.isApprovedOrOwner(msg.sender, _id),
            "ERC721: invalid token ID"
        );
        _;
    }
}

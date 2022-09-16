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

contract HandshakeSld is HandshakeNft, IHandshakeSld, HasUsdOracle, PaymentManager {
    using ERC165Checker for address;

    HandshakeTld public handshakeTldContract;
    ICommitIntent public commitIntent;
    ILabelValidator public validator;

    IGlobalRegistrationRules public contractRegistrationStrategy;

    uint256 private DECIMAL_MULTIPLIER = 1000;

    mapping(bytes32 => ISldRegistrationStrategy) public sldDefaultRegistrationStrategy;
    mapping(bytes32 => SubdomainRegistrationDetail) public subdomainRegistrationHistory;

    error MissingRegistrationStrategy();

    //interface method for price strategy
    bytes4 private constant PRICE_IN_DOLLARS_SELECTOR =
        bytes4(keccak256("getPriceInDollars(address,bytes32,string,uint256)"));

    mapping(bytes32 => bytes32) public namehashToParentMap;

    mapping(bytes32 => uint256) public royaltyPayoutAmountMap;
    mapping(bytes32 => mapping(address => address)) public royaltyPayoutAddressMap;

    constructor(HandshakeTld _tld, ICommitIntent _commitIntent)
        HandshakeNft("SLD", "Handshake SLD")
        PaymentManager(msg.sender)
    {
        handshakeTldContract = _tld;
        commitIntent = _commitIntent;
        validator = new LabelValidator();
    }

    function setHandshakeTldContract(HandshakeTld _tld) external onlyOwner {
        handshakeTldContract = _tld;
    }

    //TODO: need to make sure can't reentry this function
    function renewSubdomain(bytes32 _subdomainHash, uint256 _registrationLength) external payable {
        SubdomainRegistrationDetail memory history = subdomainRegistrationHistory[_subdomainHash];

        require(
            history.RegistrationTime + (history.RegistrationLength * 86400) > block.timestamp,
            "domain expired"
        );

        uint256 priceInDollars = getRenewalPricePerDay(history, _registrationLength);

        uint256 priceInWei = (getWeiValueOfDollar() * priceInDollars * _registrationLength) /
            DECIMAL_MULTIPLIER;
        require(priceInWei <= msg.value, "Price too low");

        history.RegistrationLength += uint72(_registrationLength);

        subdomainRegistrationHistory[_subdomainHash].RegistrationLength = history
            .RegistrationLength;

        //process the funds
        //refund excess paid (maybe due to delay in processing tx and $ price changing)
        uint256 refund = msg.value - priceInWei;
        payable(msg.sender).transfer(refund);

        address parentAddress = getOwnerOfParent(_subdomainHash);
        distributePrimaryFunds(parentAddress, priceInWei);
    }

    function getRenewalPricePerDay(
        SubdomainRegistrationDetail memory _history,
        uint256 _registrationLength
    ) public view returns (uint256) {
        uint256 registrationYears = (_registrationLength / 365); //get the annual rate

        registrationYears = registrationYears > 10 ? 10 : registrationYears;

        uint256 renewalCostPerAnnum = _history.RegistrationPriceSnapshot[registrationYears - 1] /
            registrationYears;
        return renewalCostPerAnnum / 365;
    }

    function purchaseMultipleSld(
        string[] calldata _label,
        bytes32[] calldata _secret,
        uint256[] calldata _registrationLength,
        bytes32[] calldata _parentNamehash,
        address[] calldata _recipient
    ) public payable {
        // uint256 expectedLength = _label.length;

        require(
            _label.length == _secret.length &&
                _label.length == _registrationLength.length &&
                _label.length == _parentNamehash.length &&
                _label.length == _recipient.length,
            "all arrays should be the same length"
        );
        {
            uint256 priceInWei;
            uint256 weiValueOfDollar = getWeiValueOfDollar();

            for (uint256 i; i < _label.length; ) {
                priceInWei += purchaseDomainReturnPrice(
                    _parentNamehash[i],
                    _label[i],
                    _registrationLength[i],
                    _secret[i],
                    _recipient[i],
                    weiValueOfDollar
                );

                unchecked {
                    ++i;
                }
            }

            require(priceInWei <= msg.value, "Price too low");

            uint256 refund = msg.value - priceInWei;
            payable(msg.sender).transfer(refund);
        }
    }

    function registerSld(
        address _to,
        bytes32 _tldNamehash,
        bytes32 _sldNamehash
    ) external {}

    function purchaseDomainReturnPrice(
        bytes32 _parentNamehash,
        string calldata _label,
        uint256 _registrationLength,
        bytes32 _secret,
        address _recipient
    ) private returns (uint256) {
        //will revert if pricing strategy does not exist.
        ISldRegistrationStrategy priceStrat = getRegistrationStrategy(_parentNamehash);

        uint256 domainDollarCost = priceStrat.getPriceInDollars(
            msg.sender,
            _parentNamehash,
            _label,
            _registrationLength
        );

        require(
            contractRegistrationStrategy.canRegister(
                msg.sender,
                _parentNamehash,
                _label,
                _registrationLength,
                domainDollarCost
            ),
            "not eligible"
        );

        purchaseSld(
            _label,
            _secret,
            _registrationLength,
            _parentNamehash,
            _recipient == address(0) ? msg.sender : _recipient
        );

        addRegistrationDetails(
            getNamehash(_parentNamehash, _label),
            domainDollarCost,
            _registrationLength,
            priceStrat,
            _parentNamehash,
            _label
        );

        return domainDollarCost;
    }

    function purchaseDomainReturnPrice(
        bytes32 _parentNamehash,
        string calldata _label,
        uint256 _registrationLength,
        bytes32 _secret,
        address _recipient,
        uint256 _weiToDollar
    ) private returns (uint256 domainWeiCost) {
        //will revert if pricing strategy does not exist.
        ISldRegistrationStrategy priceStrat = getRegistrationStrategy(_parentNamehash);

        uint256 domainDollarCost = priceStrat.getPriceInDollars(
            msg.sender,
            _parentNamehash,
            _label,
            _registrationLength
        );

        require(
            contractRegistrationStrategy.canRegister(
                msg.sender,
                _parentNamehash,
                _label,
                _registrationLength,
                domainDollarCost
            ),
            "not eligible"
        );

        purchaseSld(
            _label,
            _secret,
            _registrationLength,
            _parentNamehash,
            _recipient == address(0) ? msg.sender : _recipient
        );

        bytes32 subdomainHash = getNamehash(_parentNamehash, _label);

        addRegistrationDetails(
            subdomainHash,
            domainDollarCost,
            _registrationLength,
            priceStrat,
            _parentNamehash,
            _label
        );

        uint256 priceInWei = (domainDollarCost * _weiToDollar) / DECIMAL_MULTIPLIER;

        address parentAddress = getOwnerOfParent(subdomainHash);
        distributePrimaryFunds(parentAddress, priceInWei);

        return priceInWei;
    }

    function purchaseSingleDomain(
        string calldata _label,
        bytes32 _secret,
        uint256 _registrationLength,
        bytes32 _parentNamehash,
        bytes32[] calldata _proofs,
        address _recipient
    ) external payable {
        ISldRegistrationStrategy strategy = getRegistrationStrategy(_parentNamehash);
        uint256 domainDollarCost = strategy.getPriceInDollars(
            msg.sender,
            _parentNamehash,
            _label,
            _registrationLength
        );

        //refund any excess, can't reentry as token will already exist

        purchaseSld(
            _label,
            _secret,
            _registrationLength,
            _parentNamehash,
            _recipient == address(0) ? msg.sender : _recipient
        );

        addRegistrationDetails(
            getNamehash(_parentNamehash, _label),
            domainDollarCost,
            _registrationLength,
            strategy,
            _parentNamehash,
            _label
        );

        uint256 priceInWei = (getWeiValueOfDollar() * domainDollarCost) / DECIMAL_MULTIPLIER;

        require(priceInWei <= msg.value, "Price too low");

        uint256 refund = msg.value - priceInWei;
        payable(msg.sender).transfer(refund);
        console.log("here we go");
        distributePrimaryFunds(getOwnerOfParent(getNamehash(_parentNamehash, _label)), priceInWei);
    }

    function purchaseSld(
        string calldata _label,
        bytes32 _secret,
        uint256 _registrationLength,
        bytes32 _parentNamehash,
        address _recipient
    ) private returns (uint256) {
        require(validator.isValidLabel(_label), "invalid name");

        bytes32 namehash = getNamehash(_parentNamehash, _label);
        console.log("actual namehash");
        console.log(uint256(namehash));
        require(commitIntent.allowedCommit(namehash, _secret, msg.sender), "commit not allowed");
        require(canRegister(namehash), "Subdomain already registered");

        uint256 id = uint256(namehash);

        //if it exists and we got this far
        //then we just burn the token and mint it to the new owner.
        if (exists(id)) {
            _burn(id);
        }

        _safeMint(_recipient == address(0) ? msg.sender : _recipient, id);

        namehashToLabelMap[namehash] = _label;
        namehashToParentMap[namehash] = _parentNamehash;
    }

    function addRegistrationDetails(
        bytes32 _namehash,
        uint256 _price,
        uint256 _days,
        ISldRegistrationStrategy _strategy,
        bytes32 _parentNamehash,
        string calldata _label
    ) private {
        uint48[10] memory arr;

        for (uint256 i; i < arr.length; ) {
            uint256 price = _strategy.getPriceInDollars(
                msg.sender,
                _parentNamehash,
                _label,
                (i + 1) * 365
            );

            arr[i] = uint48(price);

            unchecked {
                ++i;
            }
        }
        SubdomainRegistrationDetail memory details = SubdomainRegistrationDetail(
            uint72(block.timestamp),
            uint24(_days),
            uint24(_price),
            arr
        );
        subdomainRegistrationHistory[_namehash] = details;
    }

    function canRegister(bytes32 _namehash) private view returns (bool) {
        SubdomainRegistrationDetail memory detail = subdomainRegistrationHistory[_namehash];
        return detail.RegistrationTime + (detail.RegistrationLength * 86400) < block.timestamp;
    }

    function getWeiValueOfDollar() public view returns (uint256) {
        uint256 price = usdOracle.getPrice();

        return (1 ether * 100000000) / price;
    }

    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        bytes32 parentNamehash = namehashToParentMap[bytes32(tokenId)];
        uint256 parentId = uint256(parentNamehash);

        address owner = exists(parentId)
            ? ownerOf(parentId)
            : handshakeTldContract.ownerOf(parentId);

        receiver = royaltyPayoutAddressMap[parentNamehash][owner] == address(0)
            ? owner
            : royaltyPayoutAddressMap[parentNamehash][owner];

        royaltyAmount = royaltyPayoutAmountMap[parentNamehash] == 0
            ? 0
            : ((salePrice / 100) * royaltyPayoutAmountMap[parentNamehash]);
    }

    function updateLabelValidator(ILabelValidator _validator) public onlyOwner {
        validator = _validator;
    }

    function getRegistrationStrategy(bytes32 _parentNamehash)
        public
        view
        returns (ISldRegistrationStrategy)
    {
        if (address(0) != address(sldDefaultRegistrationStrategy[_parentNamehash])) {
            return sldDefaultRegistrationStrategy[_parentNamehash];
        } else {
            revert MissingRegistrationStrategy();
        }
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

    function getGuarenteedPrices(bytes32 _namehash)
        external
        view
        returns (uint48[10] memory _prices)
    {
        SubdomainRegistrationDetail memory detail = subdomainRegistrationHistory[_namehash];
        return detail.RegistrationPriceSnapshot;
    }

    function getOwnerOfParent(bytes32 _childHash) private view returns (address _parent) {
        uint256 id = uint256(namehashToParentMap[_childHash]);
        require(id > 0, "parent does not exist");
        _parent = exists(id) ? ownerOf(id) : handshakeTldContract.ownerOf(id);
    }

    function isApprovedOrOwnerOfChildOrParent(uint256 _id) public view returns (bool) {
        return
            handshakeTldContract.isApprovedOrOwner(msg.sender, _id) ||
            isApprovedOrOwner(msg.sender, _id);
    }

    function isApprovedOrOwner(address spender, uint256 tokenId)
        public
        view
        override(HandshakeNft, IHandshakeSld)
        returns (bool)
    {
        super.isApprovedOrOwner(spender, tokenId);
    }

    modifier onlyParentApprovedOrOwner(uint256 _id) {
        require(isApprovedOrOwnerOfChildOrParent(_id), "ERC721: invalid token ID");
        _;
    }
}

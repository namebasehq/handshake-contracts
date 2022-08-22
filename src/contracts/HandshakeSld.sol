// SPDX-License-Identifier: UNLICENSED

import "src/contracts/HandshakeERC721.sol";
import "src/contracts/HandshakeTld.sol";
import "src/contracts/SldCommitIntent.sol";
import "interfaces/ICommitIntent.sol";
import "interfaces/IHandshakeSld.sol";
import "interfaces/ISldRegistrationStrategy.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "src/structs/SubdomainDetail.sol";
import "src/structs/SubdomainRegistrationDetail.sol";
import "interfaces/IPriceOracle.sol";
import "src/contracts/UsdPriceOracle.sol";
import "src/contracts/HasUsdOracle.sol";

import {Test} from "forge-std/Test.sol";

pragma solidity ^0.8.15;

contract HandshakeSld is HandshakeERC721, IHandshakeSld, HasUsdOracle {
    using ERC165Checker for address;
    HandshakeTld public HandshakeTldContract;
    ICommitIntent public CommitIntent;
    IDomainValidator public LabelValidator;

    uint256 private DECIMAL_MULTIPLIER = 1000;

    uint256 private constant MIN_REGISTRATION_DAYS = 364;

    //moved this from tld contract so we can have subdomains of subdomains.
    mapping(bytes32 => ISldRegistrationStrategy) public SldDefaultRegistrationStrategy;
    mapping(bytes32 => SubdomainRegistrationDetail) public SubdomainRegistrationHistory;

    error MissingRegistrationStrategy();

    //interface method for price strategy
    bytes4 private constant PRICE_IN_DOLLARS_SELECTOR =
        bytes4(keccak256("getPriceInDollars(address,bytes32,string,uint256)"));

    mapping(bytes32 => bytes32) public NamehashToParentMap;

    mapping(bytes32 => uint256) public RoyaltyPayoutAmountMap;
    mapping(bytes32 => mapping(address => address)) public RoyaltyPayoutAddressMap;

    constructor() HandshakeERC721("HSLD", "Handshake Second Level Domain") {
        HandshakeTldContract = new HandshakeTld(msg.sender);
        HandshakeTldContract.transferOwnership(msg.sender);

        CommitIntent = new SldCommitIntent(msg.sender);
        LabelValidator = new DomainLabelValidator();
    }

    function getPricingStrategy(bytes32 _parentNamehash)
        public
        view
        returns (ISldRegistrationStrategy)
    {
        if (
            address(SldDefaultRegistrationStrategy[_parentNamehash]).supportsInterface(
                PRICE_IN_DOLLARS_SELECTOR
            )
        ) {
            return SldDefaultRegistrationStrategy[_parentNamehash];
        } else {
            revert MissingRegistrationStrategy();
        }
    }

    //TODO: need to make sure can't reentry this function
    function renewSubdomain(bytes32 _subdomainHash, uint256 _registrationLength)
        external
        payable
    {
        SubdomainRegistrationDetail memory history = SubdomainRegistrationHistory[
            _subdomainHash
        ];

        require(
            history.RegistrationTime + (history.RegistrationLength * 86400) >
                block.timestamp,
            "domain expired"
        );

        uint256 priceInDollars = getRenewalPricePerDay(history, _registrationLength);

        uint256 priceInWei = (getWeiValueOfDollar() *
            priceInDollars *
            _registrationLength) / DECIMAL_MULTIPLIER;
        require(priceInWei <= msg.value, "Price too low");

        uint256 refund = msg.value - priceInWei;
        payable(msg.sender).transfer(refund);

        history.RegistrationLength += uint72(_registrationLength);

        SubdomainRegistrationHistory[_subdomainHash].RegistrationLength = history
            .RegistrationLength;
    }

    function getRenewalPricePerDay(
        SubdomainRegistrationDetail memory _history,
        uint256 _registrationLength
    ) public view returns (uint256) {
        require(_registrationLength > 364, "365 day minimum renewal");
        uint256 registrationYears = (_registrationLength / 365); //get the annual rate

        registrationYears = registrationYears > 10 ? 10 : registrationYears;

        uint256 renewalCostPerAnnum = _history.RegistrationPriceSnapshot[
            registrationYears - 1
        ] / registrationYears;
        return renewalCostPerAnnum / 365;
    }

    function purchaseMultipleSld(
        string[] calldata _label,
        bytes32[] calldata _secret,
        uint256[] calldata _registrationLength,
        bytes32[] calldata _parentNamehash,
        address[] calldata _recipient
    ) public payable {
        uint256 expectedLength = _label.length;

        require(
            expectedLength == _secret.length &&
                expectedLength == _registrationLength.length &&
                expectedLength == _parentNamehash.length &&
                expectedLength == _recipient.length,
            "all arrays should be the same length"
        );
        {
            uint256 priceInDollars;

            for (uint256 i; i < expectedLength; ) {
                priceInDollars += purchaseDomainReturnPrice(
                    _parentNamehash[i],
                    _label[i],
                    _registrationLength[i],
                    _secret[i],
                    _recipient[i]
                );

                unchecked {
                    ++i;
                }
            }

            uint256 priceInWei = (getWeiValueOfDollar() * priceInDollars) /
                DECIMAL_MULTIPLIER;
            require(priceInWei <= msg.value, "Price too low");

            uint256 refund = msg.value - priceInWei;
            payable(msg.sender).transfer(refund);
        }
    }

    function purchaseDomainReturnPrice(
        bytes32 _parentNamehash,
        string calldata _label,
        uint256 _registrationLength,
        bytes32 _secret,
        address _recipient
    ) private returns (uint256) {
        //will revert if pricing strategy does not exist.
        ISldRegistrationStrategy priceStrat = getPricingStrategy(_parentNamehash);

        uint256 domainDollarCost = priceStrat.getPriceInDollars(
            msg.sender,
            _parentNamehash,
            _label,
            _registrationLength
        );

        purchaseSld(
            _label,
            _secret,
            _registrationLength,
            _parentNamehash,
            _recipient == address(0) ? msg.sender : _recipient
        );

        addRegistrationDetails(
            getNamehash(_label, _parentNamehash),
            domainDollarCost,
            _registrationLength,
            priceStrat,
            _parentNamehash,
            _label
        );

        return domainDollarCost;
    }

    function purchaseSingleDomain(
        string calldata _label,
        bytes32 _secret,
        uint256 _registrationLength,
        bytes32 _parentNamehash,
        bytes32[] calldata _proofs,
        address _recipient
    ) external payable {
        ISldRegistrationStrategy strategy = getPricingStrategy(_parentNamehash);
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
            getNamehash(_label, _parentNamehash),
            domainDollarCost,
            _registrationLength,
            strategy,
            _parentNamehash,
            _label
        );

        uint256 priceInWei = (getWeiValueOfDollar() * domainDollarCost) /
            DECIMAL_MULTIPLIER;

        require(priceInWei <= msg.value, "Price too low");

        uint256 refund = msg.value - priceInWei;
        payable(msg.sender).transfer(refund);
    }

    function purchaseSld(
        string calldata _label,
        bytes32 _secret,
        uint256 _registrationLength,
        bytes32 _parentNamehash,
        address _recipient
    ) private returns (uint256) {
        require(LabelValidator.isValidLabel(_label), "invalid label");

        bytes32 namehash = getNamehash(_label, _parentNamehash);
        require(
            CommitIntent.allowedCommit(namehash, _secret, msg.sender),
            "commit not allowed"
        );
        require(canRegister(namehash), "Subdomain already registered");

        uint256 id = uint256(namehash);

        //if it exists and we got this far
        //then we just burn the token and mint it to the new owner.
        if (exists(id)) {
            _burn(id);
        }

        _safeMint(_recipient == address(0) ? msg.sender : _recipient, id);

        NamehashToLabelMap[namehash] = _label;
        NamehashToParentMap[namehash] = _parentNamehash;
    }

    function addRegistrationDetails(
        bytes32 _namehash,
        uint256 _price,
        uint256 _days,
        ISldRegistrationStrategy _strategy,
        bytes32 _parentNamehash,
        string calldata _label
    ) private {
        require(_days > MIN_REGISTRATION_DAYS, "Too short registration length");
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
        SubdomainRegistrationHistory[_namehash] = details;
    }

    function canRegister(bytes32 _namehash) private view returns (bool) {
        SubdomainRegistrationDetail memory detail = SubdomainRegistrationHistory[
            _namehash
        ];
        return
            detail.RegistrationTime + (detail.RegistrationLength * 86400) <
            block.timestamp;
    }

    function getWeiValueOfDollar() public view returns (uint256) {
        uint256 price = UsdOracle.getPrice();

        return (1 ether * 100000000) / price;
    }

    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        bytes32 parentNamehash = NamehashToParentMap[bytes32(tokenId)];
        uint256 parentId = uint256(parentNamehash);

        address owner = exists(parentId)
            ? ownerOf(parentId)
            : HandshakeTldContract.ownerOf(parentId);

        receiver = RoyaltyPayoutAddressMap[parentNamehash][owner] == address(0)
            ? owner
            : RoyaltyPayoutAddressMap[parentNamehash][owner];

        royaltyAmount = RoyaltyPayoutAmountMap[parentNamehash] == 0
            ? 0
            : ((salePrice / 100) * RoyaltyPayoutAmountMap[parentNamehash]);
    }

    function updateLabelValidator(IDomainValidator _validator) public onlyOwner {
        LabelValidator = _validator;
    }

    function setPricingStrategy(bytes32 _namehash, address _strategy)
        public
        onlyParentApprovedOrOwner(uint256(_namehash))
    {
        require(
            _strategy.supportsInterface(PRICE_IN_DOLLARS_SELECTOR),
            "missing interface for price strategy"
        );
        SldDefaultRegistrationStrategy[_namehash] = ISldRegistrationStrategy(_strategy);
    }

    function setRoyaltyPayoutAmount(uint256 _id, uint256 _amount)
        public
        onlyParentApprovedOrOwner(_id)
    {
        require(_amount <= 10, "10% maximum royalty on SLD");
        RoyaltyPayoutAmountMap[bytes32(_id)] = _amount;
    }

    function setRoyaltyPayoutAddress(uint256 _id, address _addr)
        public
        onlyParentApprovedOrOwner(_id)
    {
        require(_addr != address(0), "cannot set to zero address");
        address parentOwner = exists(_id)
            ? ownerOf(_id)
            : HandshakeTldContract.ownerOf(_id);
        RoyaltyPayoutAddressMap[bytes32(_id)][parentOwner] = _addr;
    }

    function isApprovedOrOwnerOfChildOrParent(uint256 _id) public returns (bool) {
        return
            HandshakeTldContract.isApproved(_id, msg.sender) ||
            isApproved(_id, msg.sender);
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
        ISldRegistrationStrategy priceStrat = getPricingStrategy(parentHash);

        uint256 priceInDollars = priceStrat.getPriceInDollars(
            _recipient,
            parentHash,
            _label,
            _registrationLength
        );

        uint256 royaltyAmount = RoyaltyPayoutAmountMap[parentHash];

        SubdomainDetail memory detail = SubdomainDetail(
            uint256(getNamehash(_label, parentHash)),
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

    function setPriceOracle(IPriceOracle _oracle) public onlyOwner {
        UsdOracle = _oracle;
        emit NewUsdOracle(address(_oracle));
    }

    function getGuarenteedPrices(bytes32 _namehash)
        external
        returns (uint48[10] memory _prices)
    {
        SubdomainRegistrationDetail memory detail = SubdomainRegistrationHistory[
            _namehash
        ];
        return detail.RegistrationPriceSnapshot;
    }

    modifier onlyParentApprovedOrOwner(uint256 _id) {
        require(
            isApprovedOrOwnerOfChildOrParent(_id),
            "not approved or owner of parent domain"
        );
        _;
    }
}

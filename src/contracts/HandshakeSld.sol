// SPDX-License-Identifier: UNLICENSED

import "src/contracts/HandshakeERC721.sol";
import "src/contracts/HandshakeTld.sol";
import "src/contracts/SldCommitIntent.sol";
import "interfaces/ICommitIntent.sol";
import "interfaces/IHandshakeSld.sol";
import "interfaces/ISldPriceStrategy.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "src/structs/SubdomainDetail.sol";
import "src/structs/SubdomainRegistrationDetail.sol";
import "interfaces/IPriceOracle.sol";
import "src/contracts/UsdPriceOracle.sol";

pragma solidity ^0.8.15;

contract HandshakeSld is HandshakeERC721, IHandshakeSld {
    using ERC165Checker for address;
    HandshakeTld public HandshakeTldContract;
    ICommitIntent public CommitIntent;
    IDomainValidator public LabelValidator;

    IPriceOracle public UsdOracle = new UsdPriceOracle();

    event NewUsdOracle(address indexed _usdEthPriceOracle);

    //moved this from tld contract so we can have subdomains of subdomains.
    mapping(bytes32 => ISldPriceStrategy) public SldDefaultPriceStrategy;
    mapping(bytes32 => SubdomainRegistrationDetail) public SubdomainRegistrationHistory;

    error MissingPriceStrategy();

    //interface method for price strategy
    bytes4 private constant PRICE_IN_DOLLARS_SELECTOR =
        bytes4(keccak256("getPriceInDollars(address,bytes32,string,uint256,bytes32[])"));

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
        returns (ISldPriceStrategy)
    {
        if (
            address(SldDefaultPriceStrategy[_parentNamehash]).supportsInterface(
                PRICE_IN_DOLLARS_SELECTOR
            )
        ) {
            return SldDefaultPriceStrategy[_parentNamehash];
        } else {
            revert MissingPriceStrategy();
        }
    }

    function purchaseMultipleSld(
        string[] calldata _label,
        bytes32[] calldata _secret,
        uint256[] calldata _registrationLength,
        bytes32[] calldata _parentNamehash,
        bytes32[][] calldata _proofs,
        address[] calldata _recipient
    ) public payable {
        uint256 expectedLength = _label.length;
        require(
            expectedLength ^
                _secret.length ^
                _registrationLength.length ^
                _parentNamehash.length ^
                _proofs.length ^
                _recipient.length ==
                0,
            "all arrays should be the same length"
        );

        uint256 priceInDollars;
        uint256 domainDollarCost;

        for (uint256 i; i < expectedLength; ) {
            //will revert if pricing strategy does not exist.
            ISldPriceStrategy priceStrat = getPricingStrategy(_parentNamehash[i]);

            domainDollarCost = priceStrat.getPriceInDollars(
                msg.sender,
                _parentNamehash[i],
                _label[i],
                _registrationLength[i],
                _proofs[i]
            );

            priceInDollars += domainDollarCost;

            //refund any excess, can't reentry as token will already exist

            purchaseSld(
                _label[i],
                _secret[i],
                _registrationLength[i],
                _parentNamehash[i],
                _proofs[i],
                _recipient[i] == address(0) ? msg.sender : _recipient[i]
            );

            addRegistrationDetails(
                getNamehash(_label[i], _parentNamehash[i]),
                domainDollarCost,
                _registrationLength[i]
            );

            unchecked {
                ++i;
            }
        }

        uint256 priceInWei = getWeiValueOfDollar() * priceInDollars;
        require(priceInWei <= msg.value, "Price too low");

        //uint256 refund = msg.value - priceInWei;
        //refund here
    }

    function purchaseSld(
        string calldata _label,
        bytes32 _secret,
        uint256 _registrationLength,
        bytes32 _parentNamehash,
        bytes32[] calldata _proofs
    ) public payable {
        purchaseSld(
            _label,
            _secret,
            _registrationLength,
            _parentNamehash,
            _proofs,
            msg.sender
        );
    }

    function purchaseSld(
        string calldata _label,
        bytes32 _secret,
        uint256 _registrationLength,
        bytes32 _parentNamehash,
        bytes32[] calldata _proofs,
        address _recipient
    ) public payable returns (uint256) {
        require(LabelValidator.isValidLabel(_label), "invalid label");
        bytes32 namehash = getNamehash(_label, _parentNamehash);
        require(
            CommitIntent.allowedCommit(namehash, _secret, msg.sender),
            "commit not allowed"
        );
        require(canRegister(namehash), "Subdomain already registered");

        address to = _recipient == address(0) ? msg.sender : _recipient;

        uint256 id = uint256(namehash);

        //if it exists and we got this far
        //then we just burn the token and mint it to the new owner.
        if (exists(id)) {
            _burn(id);
        }

        _safeMint(to, id);

        NamehashToLabelMap[namehash] = _label;
        NamehashToParentMap[namehash] = _parentNamehash;
    }

    function addRegistrationDetails(
        bytes32 _namehash,
        uint256 _price,
        uint256 _days
    ) private {
        SubdomainRegistrationDetail memory details = SubdomainRegistrationDetail(
            uint72(block.timestamp),
            uint24(_days),
            uint24(_price)
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

        address payoutAddress = RoyaltyPayoutAddressMap[parentNamehash][owner] ==
            address(0)
            ? owner
            : RoyaltyPayoutAddressMap[parentNamehash][owner];

        uint256 royaltyAmount = RoyaltyPayoutAmountMap[parentNamehash] == 0
            ? 0
            : ((salePrice / 100) * RoyaltyPayoutAmountMap[parentNamehash]);

        return (payoutAddress, royaltyAmount);
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
        SldDefaultPriceStrategy[_namehash] = ISldPriceStrategy(_strategy);
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
        ISldPriceStrategy priceStrat = getPricingStrategy(parentHash);

        uint256 priceInDollars = priceStrat.getPriceInDollars(
            _recipient,
            parentHash,
            _label,
            _registrationLength,
            _proofs
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

    modifier onlyParentApprovedOrOwner(uint256 _id) {
        require(
            isApprovedOrOwnerOfChildOrParent(_id),
            "not approved or owner of parent domain"
        );
        _;
    }
}

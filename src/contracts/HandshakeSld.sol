// SPDX-License-Identifier: UNLICENSED

import "src/contracts/HandshakeERC721.sol";
import "src/contracts/HandshakeTld.sol";
import "src/contracts/SldCommitIntent.sol";
import "interfaces/ICommitIntent.sol";
import "interfaces/IHandshakeSld.sol";
import "interfaces/ISldPriceStrategy.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

pragma solidity ^0.8.15;

struct SubdomainDetail {
    uint256 Id;
    uint256 ParentId;
    string Label;
    uint256 Price;
    uint256 RoyaltyAmount;
}

contract HandshakeSld is HandshakeERC721, IHandshakeSld {
    using ERC165Checker for address;
    HandshakeTld public HandshakeTldContract;
    ICommitIntent public CommitIntent;
    IDomainValidator public LabelValidator;

    error MissingPriceStrategy();

    //interface method for price strategy
    bytes4 private constant PRICE_IN_WEI_SELECTOR =
        bytes4(keccak256("getPriceInWei(address,bytes32,string,uint256,bytes32[])"));

    mapping(uint256 => bytes32) public NamehashToParentMap;

    mapping(uint256 => uint256) public RoyaltyPayoutAmountMap;
    mapping(uint256 => mapping(address => address)) public RoyaltyPayoutAddressMap;

    constructor() HandshakeERC721("HSLD", "Handshake Second Level Domain") {
        HandshakeTldContract = new HandshakeTld(msg.sender);
        HandshakeTldContract.transferOwnership(msg.sender);

        CommitIntent = new SldCommitIntent(msg.sender);
        LabelValidator = new DomainLabelValidator();
    }

    function getPricingStrategy(bytes32 _parentNamehash)
        private
        view
        returns (ISldPriceStrategy)
    {
        if (
            address(SldDefaultPriceStrategy[_parentNamehash]).supportsInterface(
                PRICE_IN_WEI_SELECTOR
            )
        ) {
            return SldDefaultPriceStrategy[_parentNamehash];
        } else if (
            address(HandshakeTldContract.SldDefaultPriceStrategy(_parentNamehash))
                .supportsInterface(PRICE_IN_WEI_SELECTOR)
        ) {
            return HandshakeTldContract.SldDefaultPriceStrategy(_parentNamehash);
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

        for (uint256 i; i < expectedLength; ) {
            address to = _recipient[i] == address(0) ? msg.sender : _recipient[i];
            purchaseSld(
                _label[i],
                _secret[i],
                _registrationLength[i],
                _parentNamehash[i],
                _proofs[i],
                to
            );

            unchecked {
                ++i;
            }
        }
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
    ) public payable {
        require(LabelValidator.isValidLabel(_label), "invalid label");

        address to = _recipient == address(0) ? msg.sender : _recipient;

        //will revert if pricing strategy does not exist.
        ISldPriceStrategy priceStrat = getPricingStrategy(_parentNamehash);

        uint256 priceInWei = priceStrat.getPriceInWei(
            msg.sender,
            _parentNamehash,
            _label,
            _registrationLength,
            _proofs
        );

        require(priceInWei <= msg.value, "invalid price");
        bytes32 namehash = getNamehash(_label, _parentNamehash);
        uint256 id = uint256(namehash);
        require(
            CommitIntent.allowedCommit(namehash, _secret, msg.sender),
            "commit not allowed"
        );

        _safeMint(to, id);

        NamehashToLabelMap[namehash] = _label;
        NamehashToParentMap[id] = _parentNamehash;
    }

    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        bytes32 parentNamehash = NamehashToParentMap[tokenId];
        uint256 parentId = uint256(parentNamehash);

        address owner = exists(parentId)
            ? ownerOf(parentId)
            : HandshakeTldContract.ownerOf(parentId);

        address payoutAddress = RoyaltyPayoutAddressMap[parentId][owner] == address(0)
            ? owner
            : RoyaltyPayoutAddressMap[parentId][owner];
        uint256 royaltyAmount = RoyaltyPayoutAmountMap[parentId] == 0
            ? 0
            : salePrice / RoyaltyPayoutAmountMap[parentId] / 10;

        return (payoutAddress, royaltyAmount);
    }

    function updateLabelValidator(IDomainValidator _validator) public onlyOwner {
        LabelValidator = _validator;
    }

    function setRoyaltyPayoutAmount(uint256 _id, uint256 _amount)
        public
        onlyParentApprovedOrOwner(_id)
    {
        require(_amount < 101, "10% maximum royalty on SLD");
        RoyaltyPayoutAmountMap[_id] = _amount;
    }

    function setRoyaltyPayoutAddress(uint256 _id, address _addr)
        public
        onlyParentApprovedOrOwner(_id)
    {
        require(_addr != address(0), "cannot set to zero address");
        address parentOwner = exists(_id)
            ? ownerOf(_id)
            : HandshakeTldContract.ownerOf(_id);
        RoyaltyPayoutAddressMap[_id][parentOwner] = _addr;
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

        uint256 priceInWei = priceStrat.getPriceInWei(
            _recipient,
            parentHash,
            _label,
            _registrationLength,
            _proofs
        );

        uint256 royaltyAmount = RoyaltyPayoutAmountMap[_parentId];

        SubdomainDetail memory detail = SubdomainDetail(
            uint256(getNamehash(_label, parentHash)),
            _parentId,
            _label,
            priceInWei,
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

    modifier onlyParentApprovedOrOwner(uint256 _id) {
        require(
            isApprovedOrOwnerOfChildOrParent(_id),
            "not approved or owner of parent domain"
        );
        _;
    }
}

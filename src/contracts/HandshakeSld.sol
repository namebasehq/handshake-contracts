// SPDX-License-Identifier: UNLICENSED

import "src/contracts/HandshakeERC721.sol";
import "src/contracts/HandshakeTld.sol";
import "src/contracts/SldCommitIntent.sol";
import "interfaces/ICommitIntent.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

pragma solidity ^0.8.15;

contract HandshakeSld is HandshakeERC721 {
    using ERC165Checker for address;
    HandshakeTld public HandshakeTldContract;
    ICommitIntent public CommitIntent;
    IDomainValidator public LabelValidator;

    //interface method for price strategy
    bytes4 private constant PRICE_IN_WEI_SELECTOR =
        bytes4(keccak256("getPriceInWei(address,bytes32,string,uint256,bytes32[])"));

    mapping(uint256 => bytes32) public NamehashToParentMap;

    mapping(uint256 => uint256) public RoyaltyPayoutAmountMap;
    mapping(uint256 => mapping(address => address)) public RoyaltyPayoutAddressMap;

    constructor() HandshakeERC721("HSLD", "Handshake Second Level Domain") {
        HandshakeTldContract = new HandshakeTld();
        HandshakeTldContract.transferOwnership(msg.sender);

        CommitIntent = new SldCommitIntent(msg.sender);
        LabelValidator = new DomainLabelValidator();
    }

    function purchaseSld(
        string calldata _label,
        bytes32 _secret,
        uint256 _registrationLength,
        bytes32 _parentNamehash,
        bytes32[] calldata _proofs
    ) public payable {
        require(LabelValidator.isValidLabel(_label), "invalid label");
        require(
            address(SldDefaultPriceStrategy[_parentNamehash]).supportsInterface(
                PRICE_IN_WEI_SELECTOR
            ),
            "does not implement price strategy"
        );

        uint256 priceInWei = SldDefaultPriceStrategy[_parentNamehash].getPriceInWei(
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

        _safeMint(msg.sender, id);

        NamehashToLabelMap[namehash] = _label;
        NamehashToParentMap[id] = _parentNamehash;
    }

    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        require(false, "not implemented");
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
        RoyaltyPayoutAddressMap[_id][getOwnerOfParent(_id)] = _addr;
    }

    function getOwnerOfParent(uint256 _id) private returns (address) {
        return HandshakeTldContract.ownerOf(_id);
    }

    modifier onlyParentApprovedOrOwner(uint256 _id) {
        require(
            HandshakeTldContract.isApproved(_id, msg.sender) ||
                isApproved(_id, msg.sender),
            "not approved or owner of parent domain"
        );
        _;
    }
}

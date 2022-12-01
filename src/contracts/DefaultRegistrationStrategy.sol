// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Namehash} from "utils/Namehash.sol";
import "interfaces/ISldRegistrationStrategy.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "interfaces/IHandshakeTld.sol";
import "src/utils/Multicallable.sol";

contract DefaultRegistrationStrategy is ISldRegistrationStrategy, Ownable, Multicallable {
    IHandshakeTld private tldContract;

    mapping(bytes32 => address) public reservedNames;
    mapping(bytes32 => uint256) public premiumNames;
    mapping(bytes32 => mapping(address => uint256)) public addressDiscounts;
    mapping(bytes32 => uint256[]) public lengthCost;
    mapping(bytes32 => uint256[]) public multiYearDiscount;

    mapping(bytes32 => bool) public isDisabled;

    event PremiumNameSet(bytes32 indexed _tokenNamehash, uint256 _price, string _label);
    event ReservedNameSet(bytes32 indexed _tokenNamehash, address indexed _claimant, string _label);

    event DiscountedAddressSet(
        bytes32 indexed _tokenNamehash,
        address indexed _claimant,
        uint256 _discount
    );

    constructor(IHandshakeTld _tld) {
        tldContract = _tld;
    }

    function setPremiumName(
        bytes32 _parentNamehash,
        string calldata _label,
        uint256 _priceInDollarsPerYear
    ) private {
        premiumNames[Namehash.getNamehash(_parentNamehash, _label)] = _priceInDollarsPerYear;
        emit PremiumNameSet(_parentNamehash, _priceInDollarsPerYear, _label);
    }

    function setReservedName(bytes32 _parentNamehash, string calldata _label, address _claimant)
        private
    {
        reservedNames[Namehash.getNamehash(_parentNamehash, _label)] = _claimant;
        emit ReservedNameSet(_parentNamehash, _claimant, _label);
    }

    function setLengthCost(bytes32 _parentNamehash, uint256[] calldata _prices)
        public
        isApprovedOrTokenOwner(_parentNamehash)
    {
        require(_prices.length < 11, "max 10 characters");

        uint256 currentPrice = type(uint256).max;
        for (uint256 i; i < _prices.length; ) {
            require(_prices[i] <= currentPrice, "must be less than or equal to previous length");
            currentPrice = _prices[i];

            unchecked {
                ++i;
            }
        }

        lengthCost[_parentNamehash] = _prices;
    }

    function setMultiYearDiscount(bytes32 _parentNamehash, uint256[] calldata _discounts)
        public
        isApprovedOrTokenOwner(_parentNamehash)
    {
        require(_discounts.length < 11, "cannot set more than 10 year discount");

        uint256 currentDiscount;

        for (uint256 i; i < _discounts.length; ) {
            require(_discounts[i] >= currentDiscount, "must be more or equal to previous year");
            currentDiscount = _discounts[i];
            require(currentDiscount < 51, "max 50% discount");

            unchecked {
                ++i;
            }
        }
        multiYearDiscount[_parentNamehash] = _discounts;
    }

    function getLengthCost(bytes32 _parentNamehash, uint256 _length)
        private
        view
        returns (uint256)
    {
        uint256[] memory prices = lengthCost[_parentNamehash];
        uint256 priceCount = prices.length;
        require(priceCount > 0, "no length prices are set");

        return (_length > priceCount - 1 ? prices[priceCount - 1] : prices[_length - 1]) * 1 ether;
    }

    function setPremiumNames(
        bytes32 _parentNamehash,
        string[] calldata _labels,
        uint256[] calldata _priceInDollarsPerYear
    ) public isApprovedOrTokenOwner(_parentNamehash) {
        require(_labels.length == _priceInDollarsPerYear.length, "array lengths do not match");

        for (uint256 i; i < _labels.length; ) {
            setPremiumName(_parentNamehash, _labels[i], _priceInDollarsPerYear[i]);

            unchecked {
                ++i;
            }
        }
    }

    function setReservedNames(
        bytes32 _parentNamehash,
        string[] calldata _labels,
        address[] calldata _claimants
    ) public isApprovedOrTokenOwner(_parentNamehash) {
        require(_labels.length == _claimants.length, "array lengths do not match");

        for (uint256 i; i < _labels.length; ) {
            setReservedName(_parentNamehash, _labels[i], _claimants[i]);

            unchecked {
                ++i;
            }
        }
    }


    function setAddressDiscounts(
        bytes32 _parentNamehash,
        address[] calldata _addresses,
        uint256[] calldata _discounts
    ) public isApprovedOrTokenOwner(_parentNamehash) {
        require(_addresses.length == _discounts.length, "array lengths do not match");

        for (uint256 i; i < _discounts.length; ) {
            require(_discounts[i] < 101, "maximum 100% discount");
            addressDiscounts[_parentNamehash][_addresses[i]] = _discounts[i];

            emit DiscountedAddressSet(_parentNamehash, _addresses[i], _discounts[i]);

            unchecked {
                ++i;
            }
        }
    }

    function setIsDisabled(bytes32 _parentNamehash, bool _isDisabled)
        external
        isApprovedOrTokenOwner(_parentNamehash)
    {
        isDisabled[_parentNamehash] = _isDisabled;
    }

    function getPriceInDollars(
        address _buyingAddress,
        bytes32 _parentNamehash,
        string memory _label,
        uint256 _registrationLength
    ) public view returns (uint256) {
        require(_registrationLength > 364, "minimum reg is 1 year");
        bytes32 namehash = Namehash.getNamehash(_parentNamehash, _label);

        uint256 annualPrice = premiumNames[namehash];

        require(
            reservedNames[namehash] == address(0) || reservedNames[namehash] == _buyingAddress,
            "reserved name"
        );

        uint256 calculatedPrice;

        if (annualPrice > 0) {
            //if it's a premium name then just use the annual rate on it.
            calculatedPrice = (annualPrice * 1 ether * _registrationLength) / 365;
        } else {
            uint256 totalPrice = (getLengthCost(_parentNamehash, bytes(_label).length) *
                _registrationLength) / 365;
            uint256 discount = getDiscount(_parentNamehash, _registrationLength / 365);
            calculatedPrice = (totalPrice * (100 - discount)) / 100;
        }

        uint256 addressDiscount = addressDiscounts[_parentNamehash][_buyingAddress];

        if (addressDiscount > 0) {
            calculatedPrice = calculatedPrice - ((calculatedPrice * addressDiscount) / 100);
        }

        uint256 minPrice = (_registrationLength * 1 ether) / 365;
        return calculatedPrice < minPrice ? minPrice : calculatedPrice;
    }

    function getDiscount(bytes32 _parentNamehash, uint256 _years) private view returns (uint256) {
        uint256[] memory discounts = multiYearDiscount[_parentNamehash];

        if (discounts.length == 0) {
            return 0;
        } else if (discounts.length > _years - 1) {
            return discounts[_years - 1];
        } else {
            return discounts[discounts.length - 1];
        }
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(IERC165, Multicallable)
        returns (bool)
    {
        return
            interfaceId == this.isDisabled.selector ||
            interfaceId == this.getPriceInDollars.selector ||
            interfaceId == this.addressDiscounts.selector ||
            super.supportsInterface(interfaceId);
    }

    modifier isApprovedOrTokenOwner(bytes32 _namehash) {
        require(
            tldContract.isApprovedOrOwner(msg.sender, uint256(_namehash)),
            "not approved or owner"
        );

        _;
    }
}

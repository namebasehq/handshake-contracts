// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Namehash} from "utils/Namehash.sol";
import "interfaces/ISldRegistrationStrategy.sol";
import "interfaces/ISldRegistrationManager.sol";
import "src/utils/Multicallable.sol";

contract DefaultRegistrationStrategy is ISldRegistrationStrategy, Multicallable {
    ISldRegistrationManager public immutable registrationManager;

    mapping(bytes32 => address) public reservedNames;
    mapping(bytes32 => uint256) public premiumNames;

    mapping(bytes32 => uint256[]) public lengthCost;
    mapping(bytes32 => uint256[]) public multiYearDiscount;

    mapping(bytes32 => bool) public isEnabled;

    event PremiumNameSet(bytes32 indexed _tokenNamehash, uint256 _price, string _label);
    event ReservedNameSet(bytes32 indexed _tokenNamehash, address indexed _claimant, string _label);

    error LengthTooLong();
    error PriceTooHigh(uint256 _minPrice);
    error DiscountTooHigh(uint256 _minDiscount);
    error DiscountTooLow(uint256 _maxDiscount);
    error NoPricesSet();
    error InvalidArrayLength();
    error RegistrationTooShort(uint256 _minLength);
    error NameReserved(address _claimant);
    error NotApprovedOrOwner();

    constructor(ISldRegistrationManager _manager) {
        registrationManager = _manager;
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
        if (_prices.length > 10) {
            revert LengthTooLong();
        }

        uint256 currentPrice = type(uint256).max;
        for (uint256 i; i < _prices.length; ) {
            if (_prices[i] > currentPrice) {
                revert PriceTooHigh(currentPrice);
            }
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
        if (_discounts.length > 10) {
            revert LengthTooLong();
        }

        uint256 currentDiscount;

        for (uint256 i; i < _discounts.length; ) {
            if (_discounts[i] < currentDiscount) {
                revert DiscountTooLow(currentDiscount);
            }
            currentDiscount = _discounts[i];

            unchecked {
                ++i;
            }
        }

        if (currentDiscount > 50) {
            revert DiscountTooHigh(50);
        }

        multiYearDiscount[_parentNamehash] = _discounts;
    }

    function getLengthCost(bytes32 _parentNamehash, uint256 _length)
        private
        view
        returns (uint256)
    {
        uint256[] storage prices = lengthCost[_parentNamehash];
        uint256 priceCount = prices.length;
        if (priceCount == 0) {
            revert NoPricesSet();
        }

        return (_length >= priceCount ? prices[priceCount - 1] : prices[_length - 1]) * 1 ether;
    }

    function setPremiumNames(
        bytes32 _parentNamehash,
        string[] calldata _labels,
        uint256[] calldata _priceInDollarsPerYear
    ) public isApprovedOrTokenOwner(_parentNamehash) {
        if (_labels.length != _priceInDollarsPerYear.length) {
            revert InvalidArrayLength();
        }

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
        if (_labels.length != _claimants.length) {
            revert InvalidArrayLength();
        }

        for (uint256 i; i < _labels.length; ) {
            setReservedName(_parentNamehash, _labels[i], _claimants[i]);

            unchecked {
                ++i;
            }
        }
    }

    function setIsEnabled(bytes32 _parentNamehash, bool _isEnabled)
        external
        isApprovedOrTokenOwner(_parentNamehash)
    {
        isEnabled[_parentNamehash] = _isEnabled;
    }

    function getPriceInDollars(
        address _buyingAddress,
        bytes32 _parentNamehash,
        string memory _label,
        uint256 _registrationLength,
        bool _isRenewal
    ) public view returns (uint256) {
        if (_registrationLength < 365) {
            revert RegistrationTooShort(365);
        }
        bytes32 namehash = Namehash.getNamehash(_parentNamehash, _label);

        if (
            !_isRenewal &&
            (reservedNames[namehash] != _buyingAddress && reservedNames[namehash] != address(0))
        ) {
            revert NameReserved(reservedNames[namehash]);
        }

        uint256 minPrice = (_registrationLength * minDollarPrice());

        uint256 calculatedPrice;
        uint256 annualPrice = premiumNames[namehash];

        if (annualPrice > 0) {
            //if it's a premium name then just use the annual rate on it.
            calculatedPrice = (annualPrice * 1 ether * _registrationLength);
        } else {
            uint256 totalPrice = (getLengthCost(_parentNamehash, bytes(_label).length) *
                _registrationLength);
            uint256 discount = getDiscount(_parentNamehash, _registrationLength / 365);
            calculatedPrice = (totalPrice * (100 - discount)) / 100;
        }

        if (calculatedPrice < minPrice) {
            return minPrice / 365;
        } else {
            return calculatedPrice / 365;
        }
    }

    function getDiscount(bytes32 _parentNamehash, uint256 _years) private view returns (uint256) {
        uint256[] storage discounts = multiYearDiscount[_parentNamehash];

        if (discounts.length == 0) {
            return 0;
        } else if (discounts.length >= _years) {
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
            interfaceId == this.isEnabled.selector ||
            interfaceId == this.getPriceInDollars.selector ||
            super.supportsInterface(interfaceId);
    }

    function minDollarPrice() private view returns (uint256) {
        return registrationManager.globalStrategy().minimumDollarPrice();
    }

    modifier isApprovedOrTokenOwner(bytes32 _namehash) {
        if (!registrationManager.tld().isApprovedOrOwner(msg.sender, uint256(_namehash))) {
            revert NotApprovedOrOwner();
        }
        _;
    }
}

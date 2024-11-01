// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Namehash} from "utils/Namehash.sol";
import "interfaces/ISldRegistrationStrategy.sol";
import "interfaces/ISldRegistrationManager.sol";
import "src/utils/Multicallable.sol";

contract DefaultRegistrationStrategy is ISldRegistrationStrategy, Multicallable {
    ISldRegistrationManager public immutable registrationManager;
    IHandshakeTld public immutable tld;

    mapping(bytes32 => address) public reservedNames;
    mapping(bytes32 => uint256) public premiumNames;

    mapping(bytes32 => uint256[]) public lengthCost;
    mapping(bytes32 => uint256[]) public multiYearDiscount;

    mapping(bytes32 => bool) public isEnabled;

    constructor(ISldRegistrationManager _manager) {
        registrationManager = _manager;
        tld = _manager.tld();
    }

    function setPremiumName(bytes32 _parentNamehash, string calldata _label, uint256 _priceInDollarsPerYear) private {
        premiumNames[Namehash.getNamehash(_parentNamehash, _label)] = _priceInDollarsPerYear;
        emit PremiumNameSet(_parentNamehash, _priceInDollarsPerYear, _label);
    }

    function setReservedName(bytes32 _parentNamehash, string calldata _label, address _claimant) private {
        reservedNames[Namehash.getNamehash(_parentNamehash, _label)] = _claimant;
        emit ReservedNameSet(_parentNamehash, _claimant, _label);
    }

    function setLengthCost(bytes32 _parentNamehash, uint256[] calldata _prices)
        public
        isApprovedOrTokenOwner(_parentNamehash)
    {
        uint256 arrayLength = _prices.length;
        require(arrayLength < 11, "max 10 characters");

        uint256 currentPrice = type(uint256).max;
        for (uint256 i; i < arrayLength;) {
            uint256 price = _prices[i];
            require(price <= currentPrice, "must be less than or equal to previous length");
            currentPrice = price;

            unchecked {
                ++i;
            }
        }
        emit LengthCostSet(_parentNamehash, _prices);
        lengthCost[_parentNamehash] = _prices;
    }

    function setMultiYearDiscount(bytes32 _parentNamehash, uint256[] calldata _discounts)
        public
        isApprovedOrTokenOwner(_parentNamehash)
    {
        uint256 arrayLength = _discounts.length;
        require(arrayLength < 11, "cannot set more than 10 year discount");

        uint256 currentDiscount;

        for (uint256 i; i < arrayLength;) {
            require(_discounts[i] >= currentDiscount, "must be more or equal to previous year");
            currentDiscount = _discounts[i];

            unchecked {
                ++i;
            }
        }
        require(currentDiscount < 51, "max 50% discount");

        emit MultiYearDiscountSet(_parentNamehash, _discounts);
        multiYearDiscount[_parentNamehash] = _discounts;
    }

    function getLengthCost(bytes32 _parentNamehash, uint256 _length) private view returns (uint256) {
        uint256[] storage prices = lengthCost[_parentNamehash];
        uint256 priceCount = prices.length;
        require(priceCount > 0, "no length prices are set");

        return (_length >= priceCount ? prices[priceCount - 1] : prices[_length - 1]) * 1 ether;
    }

    function setPremiumNames(
        bytes32 _parentNamehash,
        string[] calldata _labels,
        uint256[] calldata _priceInDollarsPerYear
    ) public isApprovedOrTokenOwner(_parentNamehash) {
        uint256 arrayLength = _labels.length;
        require(arrayLength == _priceInDollarsPerYear.length, "array lengths do not match");

        for (uint256 i; i < arrayLength;) {
            setPremiumName(_parentNamehash, _labels[i], _priceInDollarsPerYear[i]);

            unchecked {
                ++i;
            }
        }
    }

    function setReservedNames(bytes32 _parentNamehash, string[] calldata _labels, address[] calldata _claimants)
        public
        isApprovedOrTokenOwner(_parentNamehash)
    {
        uint256 arrayLength = _labels.length;
        require(arrayLength == _claimants.length, "array lengths do not match");

        for (uint256 i; i < arrayLength;) {
            setReservedName(_parentNamehash, _labels[i], _claimants[i]);

            unchecked {
                ++i;
            }
        }
    }

    function setIsEnabled(bytes32 _parentNamehash, bool _isEnabled) external isApprovedOrTokenOwner(_parentNamehash) {
        isEnabled[_parentNamehash] = _isEnabled;
        emit EnabledSet(_parentNamehash, _isEnabled);
    }

    function getPriceInDollars(
        address _buyingAddress,
        bytes32 _parentNamehash,
        string memory _label,
        uint256 _registrationLength,
        bool _isRenewal
    ) public view returns (uint256) {
        require(_registrationLength > 0, "minimum reg is 1 day");
        bytes32 namehash = Namehash.getNamehash(_parentNamehash, _label);

        require(
            reservedNames[namehash] == address(0) || reservedNames[namehash] == _buyingAddress || _isRenewal,
            "reserved name"
        );

        uint256 minPrice = (_registrationLength * registrationManager.globalStrategy().minimumDollarPrice());

        uint256 calculatedPrice;
        uint256 annualPrice = premiumNames[namehash];

        if (annualPrice > 0) {
            //if it's a premium name then just use the annual rate on it.
            calculatedPrice = (annualPrice * 1 ether * _registrationLength);
        } else {
            uint256 totalPrice = (getLengthCost(_parentNamehash, bytes(_label).length) * _registrationLength);
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

        uint256 arrayLength = discounts.length;

        if (arrayLength == 0) {
            return 0;
        } else if (arrayLength >= _years) {
            return discounts[_years - 1];
        } else {
            return discounts[arrayLength - 1];
        }
    }

    function supportsInterface(bytes4 interfaceId) public view override(IERC165, Multicallable) returns (bool) {
        return interfaceId == this.isEnabled.selector || interfaceId == this.getPriceInDollars.selector
            || super.supportsInterface(interfaceId);
    }

    modifier isApprovedOrTokenOwner(bytes32 _namehash) {
        require(tld.isApprovedOrOwner(msg.sender, uint256(_namehash)), "not approved or owner");

        _;
    }
}

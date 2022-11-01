// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Namehash} from "utils/Namehash.sol";
import "interfaces/ISldRegistrationStrategy.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "interfaces/IHandshakeTld.sol";

contract DefaultRegistrationStrategy is ISldRegistrationStrategy, ERC165, Ownable {
    IHandshakeTld private tldContract;

    mapping(bytes32 => address) public reservedNames;
    mapping(bytes32 => uint256) public premiumNames;

    mapping(bytes32 => uint256[]) public lengthCost;
    mapping(bytes32 => uint256[]) public multiYearDiscount;

    constructor(IHandshakeTld _tld) {
        tldContract = _tld;
    }

    function setPremiumName(
        bytes32 _parentNamehash,
        string calldata _label,
        uint256 _priceInDollarsPerYear
    ) private {
        premiumNames[Namehash.getNamehash(_parentNamehash, _label)] = _priceInDollarsPerYear;
    }

    function setReservedName(
        bytes32 _parentNamehash,
        string calldata _label,
        address _claimant
    ) private {
        reservedNames[Namehash.getNamehash(_parentNamehash, _label)] = _claimant;
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

    function getPriceInDollars(
        address _buyingAddress,
        bytes32 _parentNamehash,
        string memory _label,
        uint256 _registrationLength
    ) public view returns (uint256) {
        require(_registrationLength > 364, "minimum reg is 1 year");
        bytes32 namehash = Namehash.getNamehash(_parentNamehash, _label);

        uint256 annualPrice = premiumNames[namehash];
        if (reservedNames[namehash] == _buyingAddress) {
            //reserved names always $1 per year.
            return (_registrationLength * 1 ether) / 365;
        } 
        else {
            require(reservedNames[namehash] == address(0), "reserved name");
        }
        
        if (annualPrice > 0) {
            //if it's a premium name then just use the annual rate on it.
            uint256 totalPrice = (annualPrice * 1 ether * _registrationLength) / 365;

            return totalPrice;
        } else {
            uint256 totalPrice = (getLengthCost(_parentNamehash, bytes(_label).length) *
                _registrationLength) / 365;
            uint256 discount = getDiscount(_parentNamehash, _registrationLength / 365);
            uint256 calculatedPrice = (totalPrice * (100 - discount)) / 100;
            uint256 minPrice = (_registrationLength * 1 ether) / 365;
            return calculatedPrice < minPrice ? minPrice : calculatedPrice;
        }
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
        override(ERC165, IERC165)
        returns (bool)
    {
        return
            interfaceId == this.getPriceInDollars.selector ||
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

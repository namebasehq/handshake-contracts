// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "interfaces/ISldRegistrationStrategy.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "interfaces/IHandshakeSld.sol";
import {console} from "forge-std/console.sol";

contract DefaultRegistrationStrategy is ISldRegistrationStrategy, ERC165, Ownable {
    IHandshakeSld private subdomainContract;

    mapping(bytes32 => address) public reservedNames;
    mapping(bytes32 => uint256) public premiumNames;

    mapping(bytes32 => uint256[]) public lengthCost;
    mapping(bytes32 => uint256[]) public multiYearDiscount;

    function getNamehash(string memory _label, bytes32 _parentHash) private pure returns (bytes32) {
        bytes32 encoded_label = keccak256(abi.encodePacked(_label));
        bytes32 big_hash = keccak256(abi.encodePacked(_parentHash, encoded_label));

        return big_hash;
    }

    constructor(IHandshakeSld _sld) {
        subdomainContract = _sld;
    }

    function setPremiumName(
        bytes32 _parentNamehash,
        string calldata _label,
        uint256 _priceInDollarsPerYear
    ) private {
        premiumNames[
            keccak256(abi.encodePacked(keccak256(abi.encodePacked(_label)), _parentNamehash))
        ] = _priceInDollarsPerYear;
    }

    function setReservedName(
        bytes32 _parentNamehash,
        string calldata _label,
        address _claimant
    ) private {
        reservedNames[
            keccak256(abi.encodePacked(keccak256(abi.encodePacked(_label)), _parentNamehash))
        ] = _claimant;
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
        uint256 len = _labels.length;
        require(len == _priceInDollarsPerYear.length, "array lengths do not match");

        for (uint256 i; i < len; ) {
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
        uint256 len = _labels.length;
        require(len == _claimants.length, "array lengths do not match");

        for (uint256 i; i < len; ) {
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
        bytes32 namehash = keccak256(
            abi.encodePacked(keccak256(abi.encodePacked(_label)), _parentNamehash)
        );

        uint256 annualPrice = premiumNames[namehash];
        if (reservedNames[namehash] == _buyingAddress) {
            return (_registrationLength * 1 ether) / 365;
        } else if (annualPrice > 0) {
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

    function getPriceInDollarsWithProofs(
        address _buyingAddress,
        bytes32 _parentNamehash,
        string calldata _label,
        bytes32[] calldata _proofs,
        uint256 _registrationLength
    ) external view returns (uint256) {
        return getPriceInDollars(_buyingAddress, _parentNamehash, _label, _registrationLength);
    }

    function getDiscount(bytes32 _parentNamehash, uint256 _years) private view returns (uint256) {
        require(_years > 0, "minimum reg is 1 year");

        uint256[] memory discounts = multiYearDiscount[_parentNamehash];
        uint256 arrLength = discounts.length;

        if (arrLength == 0) {
            return 0;
        } else if (arrLength > _years - 1) {
            return discounts[_years - 1];
        } else {
            return discounts[arrLength - 1];
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
            interfaceId == this.getPriceInDollarsWithProofs.selector ||
            super.supportsInterface(interfaceId);
    }

    modifier isApprovedOrTokenOwner(bytes32 _namehash) {
        require(
            subdomainContract.isApprovedOrOwner(msg.sender, uint256(_namehash)),
            "not approved or owner"
        );

        _;
    }
}

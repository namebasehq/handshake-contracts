// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "interfaces/IHandshakeSld.sol";
import "interfaces/IHandshakeTld.sol";
import "interfaces/ILabelValidator.sol";
import "interfaces/ICommitIntent.sol";
import "interfaces/IGlobalRegistrationRules.sol";
import "interfaces/ISldRegistrationManager.sol";
import "interfaces/IPriceOracle.sol";
import "structs/SubdomainRegistrationDetail.sol";
import "src/utils/Namehash.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "./PaymentManager.sol";
import "./HasUsdOracle.sol";

import {console} from "forge-std/console.sol";

contract SldRegistrationManager is Ownable, ISldRegistrationManager, PaymentManager, HasUsdOracle {
    using ERC165Checker for address;

    mapping(bytes32 => SubdomainRegistrationDetail) public subdomainRegistrationHistory;
    ILabelValidator public labelValidator;
    IGlobalRegistrationRules public globalStrategy;
    IHandshakeSld public sld;
    IHandshakeTld public tld;

    ICommitIntent public commitIntent;

    constructor(
        IHandshakeTld _tld,
        IHandshakeSld _sld,
        ICommitIntent _commitIntent,
        IPriceOracle _oracle
    ) PaymentManager(msg.sender) {
        sld = _sld;
        tld = _tld;
        commitIntent = _commitIntent;
        updatePriceOracle(_oracle);
    }

    function registerSld(
        string calldata _label,
        bytes32 _secret,
        uint256 _registrationLength,
        bytes32 _parentNamehash,
        address _recipient
    ) external payable {
        bytes32 sldNamehash = Namehash.getNamehash(_parentNamehash, _label);
        require(commitIntent.allowedCommit(sldNamehash, _secret, msg.sender), "not allowed");
        require(labelValidator.isValidLabel(_label), "invalid label");

        ISldRegistrationStrategy strategy = sld.getRegistrationStrategy(_parentNamehash);

        require(address(strategy) != address(0), "no registration strategy");

        uint256 dollarPrice = strategy.getPriceInDollars(
            msg.sender,
            _parentNamehash,
            _label,
            _registrationLength
        );

        require(
            globalStrategy.canRegister(
                msg.sender,
                _parentNamehash,
                _label,
                _registrationLength,
                dollarPrice
            ),
            "failed global strategy"
        );

        require(canRegister(sldNamehash), "domain already registered");

        sld.registerSld(
            _recipient == address(0) ? msg.sender : _recipient,
            _parentNamehash,
            sldNamehash
        );

        addRegistrationDetails(
            sldNamehash,
            dollarPrice,
            _registrationLength,
            strategy,
            _parentNamehash,
            _label
        );

        uint256 priceInWei = (getWeiValueOfDollar() * dollarPrice) / 1 ether;

        distributePrimaryFunds(msg.sender, tld.ownerOf(uint256(_parentNamehash)), priceInWei);
        // require(priceInWei <= msg.value, "price too low");

        //  uint256 refund = msg.value - priceInWei;

        //  console.log("value in contract", address(this).balance);
        //  if (refund > 0) {
        //      payable(msg.sender).transfer(refund);
        //  }
    }

    function renewSubdomain(
        string calldata _label,
        bytes32 _parentNamehash,
        uint80 _registrationLength
    ) external payable {
        bytes32 subdomainNamehash = Namehash.getNamehash(_parentNamehash, _label);

        require(!canRegister(subdomainNamehash), "invalid domain");

        SubdomainRegistrationDetail memory detail = subdomainRegistrationHistory[subdomainNamehash];

        detail.RegistrationLength = detail.RegistrationLength + (_registrationLength * 1 days);

        subdomainRegistrationHistory[subdomainNamehash] = detail;

        console.log("renew start time", detail.RegistrationTime);

        uint256 priceInDollars = getRenewalPricePerDay(
            _parentNamehash,
            _label,
            _registrationLength
        );

        uint256 priceInWei = (getWeiValueOfDollar() * priceInDollars * _registrationLength) /
            1 ether;

        require(priceInWei <= msg.value, "Price too low");
    }

    function canRegister(bytes32 _namehash) private view returns (bool) {
        SubdomainRegistrationDetail memory detail = subdomainRegistrationHistory[_namehash];
        return (detail.RegistrationTime + detail.RegistrationLength) < block.timestamp;
    }

    function updateLabelValidator(ILabelValidator _validator) public onlyOwner {
        labelValidator = _validator;
    }

    function updateHandshakePaymentAddress(address _addr) public onlyOwner {
        handshakeWalletPayoutAddress = _addr;
    }

    function updateGlobalRegistrationStrategy(IGlobalRegistrationRules _strategy) public onlyOwner {
        globalStrategy = _strategy;
    }

    function updatePriceOracle(IPriceOracle _oracle) public onlyOwner {
        usdOracle = _oracle;
    }

    function getTenYearGuarenteedPricing(bytes32 _subdomainNamehash)
        external
        view
        returns (uint128[10] memory)
    {
        SubdomainRegistrationDetail memory details = subdomainRegistrationHistory[
            _subdomainNamehash
        ];
        return details.RegistrationPriceSnapshot;
    }

    function addRegistrationDetails(
        bytes32 _namehash,
        uint256 _price,
        uint256 _days,
        ISldRegistrationStrategy _strategy,
        bytes32 _parentNamehash,
        string calldata _label
    ) private {
        uint128[10] memory arr;

        for (uint256 i; i < arr.length; ) {
            uint256 price = _strategy.getPriceInDollars(
                msg.sender,
                _parentNamehash,
                _label,
                (i + 1) * 365
            );

            //get and save annual cost
            arr[i] = uint128(price / (i + 1));

            unchecked {
                ++i;
            }
        }

        subdomainRegistrationHistory[_namehash] = SubdomainRegistrationDetail(
            uint72(block.timestamp),
            uint80(_days * 1 days),
            uint96(_price),
            arr
        );
    }

    function getRenewalPricePerDay(
        bytes32 _parentNamehash,
        string calldata _label,
        uint256 _registrationLength
    ) public view returns (uint256) {
        bytes32 subdomainNamehash = Namehash.getNamehash(_parentNamehash, _label);
        SubdomainRegistrationDetail memory history = subdomainRegistrationHistory[
            subdomainNamehash
        ];
        uint256 registrationYears = (_registrationLength / 365); //get the annual rate

        registrationYears = registrationYears > 10 ? 10 : registrationYears;
        uint256 renewalCostPerAnnum = history.RegistrationPriceSnapshot[
            (registrationYears > 10 ? 10 : registrationYears) - 1
        ];

        ISldRegistrationStrategy strategy = sld.getRegistrationStrategy(_parentNamehash);
        uint256 price = strategy.getPriceInDollars(
            msg.sender,
            _parentNamehash,
            _label,
            _registrationLength
        );

        uint256 dailyRenewalPrice = renewalCostPerAnnum / 365;
        uint256 dailyRegistrationPrice = price / _registrationLength;

        return
            dailyRenewalPrice > dailyRegistrationPrice ? dailyRegistrationPrice : dailyRenewalPrice;
    }

    function getWeiValueOfDollar() public view returns (uint256) {
        uint256 price = usdOracle.getPrice();

        return (1 ether * 100000000) / price;
    }
}

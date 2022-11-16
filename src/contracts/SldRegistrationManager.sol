// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
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
import "./HasLabelValidator.sol";
import "forge-std/console.sol";

contract SldRegistrationManager is
    OwnableUpgradeable,
    ISldRegistrationManager,
    PaymentManager,
    HasUsdOracle,
    HasLabelValidator
{
    using ERC165Checker for address;

    mapping(bytes32 => SubdomainRegistrationDetail) public subdomainRegistrationHistory;
    mapping(bytes32 => uint256[10]) public pricesAtRegistration;

    IGlobalRegistrationRules public globalStrategy;
    IHandshakeSld public sld;
    IHandshakeTld public tld;

    ICommitIntent public commitIntent;

    function init(
        IHandshakeTld _tld,
        IHandshakeSld _sld,
        ICommitIntent _commitIntent,
        IPriceOracle _oracle,
        ILabelValidator _validator,
        IGlobalRegistrationRules _globalRules,
        address _handshakeWallet,
        address _owner
    ) public initializer {
        sld = _sld;
        tld = _tld;
        commitIntent = _commitIntent;
        globalStrategy = _globalRules;
        handshakeWalletPayoutAddress = _handshakeWallet;
        usdOracle = _oracle;
        labelValidator = _validator;
        _transferOwnership(_owner);
    }

    /**
     * @notice Register an eligible Sld. Require to send in the appropriate amount of ethereum
     * @dev Checks commitIntent, labelValidator, globalStrategy to ensure domain can be registered
     *
     * @param _label selected subdomain label. Requires to pass LabelValidator validation
     * @param _secret This is the secret generated from the commitIntent contract
     * @param _registrationLength Number of days for registration length
     * @param _parentNamehash bytes32 representation of the top level domain
     * @param _recipient Address that the sld should be sent to. address(0) will send to msg.sender
     */
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
                dollarPrice + 1 //plus 1 wei for rounding issue
            ),
            "failed global strategy"
        );

        require(canRegister(sldNamehash), "domain already registered");

        _recipient = _recipient == address(0) ? msg.sender : _recipient;

        sld.registerSld(_recipient, _parentNamehash, _label);

        addRegistrationDetails(
            sldNamehash,
            dollarPrice,
            _registrationLength,
            strategy,
            _parentNamehash,
            _label
        );

        uint256 priceInWei = (getWeiValueOfDollar() * dollarPrice) / 1 ether;

        distributePrimaryFunds(_recipient, tld.ownerOf(uint256(_parentNamehash)), priceInWei);

        emit RegisterSld(_parentNamehash, _secret, _label, block.timestamp + (_registrationLength * 1 days));
    }

    /**
     * @notice Renew an eligible Sld. Require to send in the appropriate amount of ethereum.
     *         Anyone can renew a domain, it doesn't have to be the owner of the SLD.
     * @dev We check the historic values of what the domain was sold for originally.
     *
     * @param _label selected subdomain label.
     * @param _parentNamehash bytes32 representation of the top level domain
     * @param _registrationLength Number of days for registration length
     */
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

        uint256 priceInDollars = getRenewalPricePerDay(
            _parentNamehash,
            _label,
            _registrationLength
        );

        uint256 priceInWei = (getWeiValueOfDollar() * priceInDollars * _registrationLength) /
            1 ether;

        distributePrimaryFunds(
            sld.ownerOf(uint256(subdomainNamehash)),
            tld.ownerOf(uint256(_parentNamehash)),
            priceInWei
        );

        emit RenewSld(_parentNamehash, _label, detail.RegistrationTime + detail.RegistrationLength);
    }

    function canRegister(bytes32 _namehash) private view returns (bool) {
        SubdomainRegistrationDetail memory detail = subdomainRegistrationHistory[_namehash];
        return (detail.RegistrationTime + detail.RegistrationLength) < block.timestamp;
    }

    /**
     * @notice Update the label validator contract. This just contains a function that checks the label is acceptable
     * @dev This should implement the ILabelValidator interface. Can only be run from the contract owner wallet
     *
     * @param _validator Address of the label validator. This can be updated in the future if required.
     */
    function updateLabelValidator(ILabelValidator _validator) public onlyOwner {
        labelValidator = _validator;
        emit NewLabelValidator(address(_validator));
    }

    /**
     * @notice Update the handshake payment address that primary funds are sent to
     * @dev This function can only be run by the contract owner
     * @param _addr Wallet address to set the 5% payment for primary sales to
     */
    function updateHandshakePaymentAddress(address _addr) public onlyOwner {
        require(_addr != address(0), "cannot set to zero address");
        handshakeWalletPayoutAddress = _addr;
    }

    /**
     * @notice Update the global registration strategy. As people can implement their own rules per TLD then this
     *         is to make sure that base rules cannot be updated by the TLD owners. $1 minimum etc.
     * @dev This should implement the IGlobalRegistrationRules interface. Can only be run from the contract owner wallet
     *
     * @param _strategy Address of the global strategy. This should implement the IGlobalRegistrationRules interface.
     */
    function updateGlobalRegistrationStrategy(IGlobalRegistrationRules _strategy) public onlyOwner {
        globalStrategy = _strategy;
    }

    /**
     * @notice Update the chainlink price oracle.
     * @dev Probably should never need updating.
     *
     * @param _oracle Address of the internal price oracle (this proxies to chainlink in current instance)
     */
    function updatePriceOracle(IPriceOracle _oracle) public onlyOwner {
        usdOracle = _oracle;
    }

    /**
     * @notice When a domain is registered the 10 year pricing is saved to prevent an owner updating their TLD
     *         price strategy and then gouging the price for a popular domain.
     *
     * @param _subdomainNamehash bytes32 representation of the subdomain
     * @return _history An array containing the 10 year prices that were locked in when the domain was first registered
     */
    function getTenYearGuarenteedPricing(bytes32 _subdomainNamehash)
        external
        view
        returns (uint256[10] memory _history)
    {
        _history = pricesAtRegistration[_subdomainNamehash];
    }

    function addRegistrationDetails(
        bytes32 _namehash,
        uint256 _price,
        uint256 _days,
        ISldRegistrationStrategy _strategy,
        bytes32 _parentNamehash,
        string calldata _label
    ) private {
        uint256[10] memory arr;

        for (uint256 i; i < arr.length; ) {
            uint256 price = _strategy.getPriceInDollars(
                msg.sender,
                _parentNamehash,
                _label,
                (i + 1) * 365
            );

            arr[i] = price / (i + 1);

            unchecked {
                ++i;
            }
        }

        subdomainRegistrationHistory[_namehash] = SubdomainRegistrationDetail(
            uint72(block.timestamp),
            uint80(_days * 1 days),
            uint96(_price)
        );
        pricesAtRegistration[_namehash] = arr;
    }

    /**
     * @notice When a domain is registered the 10 year pricing is saved. This function will return back the cheapest
     *         option for the renewer based on historic prices and the current strategy.
     *
     * @param _parentNamehash bytes32 representation of the top level domain
     * @param _label Label of the subdomain
     * @param _registrationLength Registration length in days
     * @return _price Returns the price in dollars (18 decimal precision)
     */
    function getRenewalPrice(
        bytes32 _parentNamehash,
        string calldata _label,
        uint256 _registrationLength
    ) public view returns (uint256 _price) {
        bytes32 subdomainNamehash = Namehash.getNamehash(_parentNamehash, _label);

        ISldRegistrationStrategy strategy = sld.getRegistrationStrategy(_parentNamehash);

        uint256 registrationYears = (_registrationLength / 365); //get the annual rate

        registrationYears = registrationYears > 10 ? 10 : registrationYears;
        uint256 renewalCostPerAnnum = pricesAtRegistration[subdomainNamehash][
            (registrationYears > 10 ? 10 : registrationYears) - 1
        ];

        uint256 registrationPrice = strategy.getPriceInDollars(
            msg.sender,
            _parentNamehash,
            _label,
            _registrationLength
        );

        uint256 renewalPrice = ((renewalCostPerAnnum < 1 ether ? 1 ether : renewalCostPerAnnum) *
            _registrationLength) / 365;

        _price = renewalPrice > registrationPrice ? registrationPrice : renewalPrice;
    }

    function getRenewalPricePerDay(
        bytes32 _parentNamehash,
        string calldata _label,
        uint256 _registrationLength
    ) public view returns (uint256 _price) {
        uint256 price = getRenewalPrice(_parentNamehash, _label, _registrationLength);
        _price = price / _registrationLength;
    }

    function getWeiValueOfDollar() public view returns (uint256) {
        require(address(0) != address(usdOracle), "usdOracle not set");
        uint256 price = usdOracle.getPrice();
        require(price > 0, "error getting price");
        return (1 ether * 100000000) / price;
    }
}

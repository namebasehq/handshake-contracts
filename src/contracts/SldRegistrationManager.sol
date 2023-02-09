// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "interfaces/IHandshakeSld.sol";
import "interfaces/IHandshakeTld.sol";
import "interfaces/ICommitIntent.sol";
import "interfaces/IGlobalRegistrationRules.sol";
import "interfaces/ISldRegistrationManager.sol";
import "structs/SldRegistrationDetail.sol";
import "structs/SldDiscountSettings.sol";
import "src/utils/Namehash.sol";
import "./PaymentManager.sol";
import "./HasUsdOracle.sol";
import "./HasLabelValidator.sol";
import "structs/SldDiscountSettings.sol";

/**
 * Registration manager for second level domains
 *
 * @title Handshake Sld Registration Manager
 * @author hodl.esf.eth
 */
contract SldRegistrationManager is
    OwnableUpgradeable,
    ISldRegistrationManager,
    PaymentManager,
    HasUsdOracle,
    HasLabelValidator
{
    using ERC165Checker for address;

    mapping(bytes32 => SldRegistrationDetail) public sldRegistrationHistory;
    mapping(bytes32 => uint80[10]) public pricesAtRegistration;

    mapping(bytes32 => mapping(address => SldDiscountSettings)) public addressDiscounts;

    IGlobalRegistrationRules public globalStrategy;
    IHandshakeSld public sld;
    IHandshakeTld public tld;

    ICommitIntent public commitIntent;

    event DiscountSet(
        bytes32 indexed _tokenNamehash,
        address indexed _claimant,
        SldDiscountSettings _discount
    );

    constructor() {
        _disableInitializers();
    }

    /**

    @notice Initialize the contract
    @dev This function is called during contract deployment and sets up the contract's dependencies. It should only be called once.
    @param _tld Address of the top level domain contract
    @param _sld Address of the second level domain contract
    @param _commitIntent Address of the commit intent contract
    @param _oracle Address of the price oracle contract
    @param _validator Address of the label validator contract
    @param _globalRules Address of the global registration rules contract
    @param _payoutWallet Address of the wallet for royalties
    @param _owner Address of the contract owner
    */
    function init(
        IHandshakeTld _tld,
        IHandshakeSld _sld,
        ICommitIntent _commitIntent,
        IPriceOracle _oracle,
        ILabelValidator _validator,
        IGlobalRegistrationRules _globalRules,
        address _payoutWallet,
        address _owner
    ) public initializer {
        sld = _sld;
        tld = _tld;
        commitIntent = _commitIntent;
        globalStrategy = _globalRules;
        feeWalletPayoutAddress = _payoutWallet;
        usdOracle = _oracle;
        labelValidator = _validator;
        _transferOwnership(_owner);
    }

    /**
     * @notice Register an eligible Sld. Require to send in the appropriate amount of ethereum
     * @dev Checks commitIntent, labelValidator, globalStrategy to ensure domain can be registered
     *
     * @param _label selected SLD label. Requires to pass LabelValidator validation
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

        require(labelValidator.isValidLabel(_label), "invalid label");

        ISldRegistrationStrategy strategy = sld.getRegistrationStrategy(_parentNamehash);
        require(
            address(strategy).supportsInterface(type(IERC165).interfaceId) &&
                strategy.supportsInterface(ISldRegistrationStrategy.getPriceInDollars.selector) &&
                strategy.supportsInterface(ISldRegistrationStrategy.isEnabled.selector),
            "registration strategy does not support interface"
        );

        require(
            strategy.isEnabled(_parentNamehash) ||
                tld.isApprovedOrOwner(msg.sender, uint256(_parentNamehash)),
            "registration strategy disabled"
        );

        uint256 dollarPrice = getRegistrationPrice(
            address(strategy),
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
                dollarPrice + 1 // plus 1 wei for rounding issue
            ),
            "failed global strategy"
        );

        require(canRegister(sldNamehash), "domain already registered");

        _recipient = _recipient == address(0) ? msg.sender : _recipient;

        sld.registerSld(_recipient, _parentNamehash, _label);

        addRegistrationDetails(sldNamehash, strategy, _parentNamehash, _label);

        sldRegistrationHistory[sldNamehash] = SldRegistrationDetail(
            uint72(block.timestamp),
            uint80(_registrationLength * 1 days),
            uint96(dollarPrice)
        );

        uint256 priceInWei = (getWeiValueOfDollar() * dollarPrice) / 1 ether;

        require(msg.value >= priceInWei, "insufficient funds");

        distributePrimaryFunds(msg.sender, tld.ownerOf(uint256(_parentNamehash)), priceInWei);

        require(
            commitIntent.allowedCommit(sldNamehash, _secret, msg.sender),
            "No valid commit intent"
        );

        emit RegisterSld(
            _parentNamehash,
            _secret,
            _label,
            block.timestamp + (_registrationLength * 1 days)
        );
    }

    function setAddressDiscounts(
        bytes32 _parentNamehash,
        address[] calldata _addresses,
        SldDiscountSettings[] calldata _discounts
    ) public {
        require(
            tld.isApprovedOrOwner(msg.sender, uint256(_parentNamehash)),
            "not approved or owner"
        );
        require(_addresses.length == _discounts.length, "array lengths do not match");

        for (uint256 i; i < _discounts.length; ) {
            addressDiscounts[_parentNamehash][_addresses[i]] = _discounts[i];

            emit DiscountSet(_parentNamehash, _addresses[i], _discounts[i]);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Renew an eligible Sld. Require to send in the appropriate amount of ethereum.
     *         Anyone can renew a domain, it doesn't have to be the owner of the SLD.
     * @dev We check the historic values of what the domain was sold for originally.
     *
     * @param _label selected SLD label.
     * @param _parentNamehash bytes32 representation of the top level domain
     * @param _registrationLength Number of days for registration length
     */
    function renewSld(string calldata _label, bytes32 _parentNamehash, uint80 _registrationLength)
        external
        payable
    {
        // no-one gonna need to extend domain more than 100 years, and we do unchecked matth
        // inside the price function
        require(_registrationLength < 36500, "must be less than 100 years");
        bytes32 sldNamehash = Namehash.getNamehash(_parentNamehash, _label);

        require(!canRegister(sldNamehash), "invalid domain");

        SldRegistrationDetail memory detail = sldRegistrationHistory[sldNamehash];

        detail.RegistrationLength = detail.RegistrationLength + (_registrationLength * 1 days);

        sldRegistrationHistory[sldNamehash] = detail;

        uint256 priceInDollars = getRenewalPrice(
            msg.sender,
            _parentNamehash,
            _label,
            _registrationLength
        );

        uint256 priceInWei = (getWeiValueOfDollar() * priceInDollars) / 1 ether;

        distributePrimaryFunds(msg.sender, tld.ownerOf(uint256(_parentNamehash)), priceInWei);

        emit RenewSld(_parentNamehash, _label, detail.RegistrationTime + detail.RegistrationLength);
    }

    function canRegister(bytes32 _namehash) private view returns (bool) {
        SldRegistrationDetail memory detail = sldRegistrationHistory[_namehash];
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
     * @param _addr Wallet address to set the commission payment for primary sales to
     */
    function updatePaymentAddress(address _addr) public onlyOwner {
        require(_addr != address(0), "cannot set to zero address");
        feeWalletPayoutAddress = _addr;
    }

    /**
     * @notice Update the handshake payment percent that primary funds are sent to
     * @dev This function can only be run by the contract owner
     * @param _percent % of primary sales to send to the handshake wallet
     */
    function updatePaymentPercent(uint256 _percent) public onlyOwner {
        require(_percent <= 10, "cannot set to more than 10 percent");
        percentCommission = _percent;
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
     * @param _sldNamehash bytes32 representation of the SLD
     * @return _history An array containing the 10 year prices that were locked in when the domain was first registered
     */
    function getTenYearGuarenteedPricing(bytes32 _sldNamehash)
        external
        view
        returns (uint80[10] memory _history)
    {
        _history = pricesAtRegistration[_sldNamehash];
    }

    // this will snapshot the base registration price for the next 10 years
    function addRegistrationDetails(
        bytes32 _namehash,
        ISldRegistrationStrategy _strategy,
        bytes32 _parentNamehash,
        string calldata _label
    ) private {
        // checked this.. Most gas efficient way to do this
        uint80[10] storage arr = pricesAtRegistration[_namehash];

        for (uint256 i; i < arr.length; ) {
            uint256 price = _strategy.getPriceInDollars(
                msg.sender,
                _parentNamehash,
                _label,
                (i + 1) * 365,
                false
            );

            arr[i] = uint80(price / (i + 1));

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice When a domain is registered the 10 year pricing is saved. This function will return back the cheapest
     *         option for the renewer based on historic prices and the current strategy.
     *
     * @param _parentNamehash bytes32 representation of the top level domain
     * @param _label Label of the SLD
     * @param _registrationLength Registration length in days
     * @return _price Returns the price in dollars (18 decimal precision)
     */
    function getRenewalPrice(
        address _addr,
        bytes32 _parentNamehash,
        string calldata _label,
        uint256 _registrationLength
    ) public view returns (uint256 _price) {
        bytes32 sldNamehash = Namehash.getNamehash(_parentNamehash, _label);

        ISldRegistrationStrategy strategy = tld.registrationStrategy(_parentNamehash);

        uint256 registrationYears = (_registrationLength / 365); //get the annual rate

        registrationYears = registrationYears > 10 ? 10 : registrationYears;

        uint256 renewalCostPerAnnum = pricesAtRegistration[sldNamehash][
            (registrationYears > 10 ? 10 : registrationYears) - 1
        ];

        uint256 registrationPrice = getRegistrationBasePrice(
            address(strategy),
            _addr,
            _parentNamehash,
            _label,
            _registrationLength,
            true // isRenewal
        );

        renewalCostPerAnnum =
            renewalCostPerAnnum -
            ((renewalCostPerAnnum * getCurrentDiscount(_parentNamehash, _addr, false)) / 100);

        //
        uint256 renewalPrice = (((
            renewalCostPerAnnum < globalStrategy.minimumDollarPrice()
                ? globalStrategy.minimumDollarPrice()
                : renewalCostPerAnnum
        ) * _registrationLength) / 365);

        _price = renewalPrice > registrationPrice ? registrationPrice : renewalPrice;
    }

    /**
     * Calls the specified registration strategy contract and calculates the price
     * used to prevent "gas griefing" attacks as the TLD owner can update the registration strategy
     *
     * @param _strategy The address of the registration strategy contract
     * @param _data The data to pass to the registration strategy contract
     * @param _registrationDays The number of days for which the domain will be registered
     * @return _price The calculated price
     */
    function safeCallRegistrationStrategyInAssembly(
        address _strategy,
        bytes memory _data,
        uint256 _registrationDays
    ) private view returns (uint256 _price) {
        bool success;

        assembly {
            let ptr := mload(0x40)

            success := staticcall(
                1000000, // 1m gas units is plenty
                _strategy,
                add(_data, 0x20),
                mload(_data),
                ptr,
                32
            )

            _price := mload(ptr)
        }

        if (!success) {
            _price = (globalStrategy.minimumDollarPrice() * _registrationDays) / 365;
        }
    }

    function getRegistrationBasePrice(
        address _strategy,
        address _addr,
        bytes32 _parentNamehash,
        string calldata _label,
        uint256 _registrationLength,
        bool _isRenewal
    ) public view returns (uint256) {
        uint256 currentPrice = safeCallRegistrationStrategyInAssembly(
            address(_strategy),
            abi.encodeWithSelector(
                ISldRegistrationStrategy.getPriceInDollars.selector,
                _addr,
                _parentNamehash,
                _label,
                _registrationLength,
                _isRenewal
            ),
            _registrationLength
        );

        uint256 minPrice = (globalStrategy.minimumDollarPrice() * _registrationLength) / 365;

        return minPrice > currentPrice ? minPrice : currentPrice;
    }

    function getRegistrationPrice(
        address _strategy,
        address _addr,
        bytes32 _parentNamehash,
        string calldata _label,
        uint256 _registrationLength
    ) public view returns (uint256) {
        uint256 currentPrice = safeCallRegistrationStrategyInAssembly(
            _strategy,
            abi.encodeWithSelector(
                ISldRegistrationStrategy.getPriceInDollars.selector,
                _addr,
                _parentNamehash,
                _label,
                _registrationLength,
                true
            ),
            _registrationLength
        );

        uint256 discount = (currentPrice * getCurrentDiscount(_parentNamehash, _addr, true)) / 100;
        currentPrice = currentPrice - discount;
        uint256 minPrice = (globalStrategy.minimumDollarPrice() * _registrationLength) / 365;
        return minPrice > currentPrice ? minPrice : currentPrice;
    }

    function getCurrentDiscount(bytes32 _parentNamehash, address _addr, bool _isRegistration)
        private
        view
        returns (uint256)
    {
        uint256 discount = 0;

        SldDiscountSettings memory discountSetting = addressDiscounts[_parentNamehash][_addr];
        SldDiscountSettings memory wildcardDiscount = addressDiscounts[_parentNamehash][address(0)];

        SldDiscountSettings memory activeDiscount = discountSetting.discountPercentage > 0
            ? discountSetting
            : wildcardDiscount;

        if (
            activeDiscount.discountPercentage > 0 &&
            activeDiscount.endTimestamp >= block.timestamp &&
            activeDiscount.startTimestamp <= block.timestamp &&
            ((activeDiscount.isRegistration && _isRegistration) ||
                (activeDiscount.isRenewal && !_isRegistration))
        ) {
            discount = activeDiscount.discountPercentage;
        }

        return discount;
    }

    /**
     * @dev Gets the full registration cost and then divides it by the number of days to get the price per day.
     * @param _addr Address of the owner of the domain.
     * @param _parentNamehash Namehash of the parent domain.
     * @param _label Label of the domain.
     * @param _registrationLength Length of the registration.
     * @return _price The renewal price per day for the domain.
     */
    function getRenewalPricePerDay(
        address _addr,
        bytes32 _parentNamehash,
        string calldata _label,
        uint256 _registrationLength
    ) public view returns (uint256 _price) {
        uint256 price = getRenewalPrice(_addr, _parentNamehash, _label, _registrationLength);

        _price = price / _registrationLength;
    }

    function getWeiValueOfDollar() public view returns (uint256) {
        require(address(0) != address(usdOracle), "usdOracle not set");
        uint256 price = usdOracle.getPrice();
        require(price > 0, "error getting price");
        return (1 ether * 100000000) / price;
    }
}

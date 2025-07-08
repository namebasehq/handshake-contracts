// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "interfaces/IHandshakeSld.sol";
import "interfaces/IHandshakeTld.sol";
import "interfaces/ICommitIntent.sol";
import "interfaces/IGlobalRegistrationRules.sol";
import "interfaces/ISldRegistrationManager.sol";
import "structs/SldRegistrationDetail.sol";
import "src/utils/Namehash.sol";
import "./PaymentManager.sol";
import "./HasUsdOracle.sol";
import "./HasLabelValidator.sol";
import "structs/SldDiscountSettings.sol";
import "structs/EIP712Domain.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

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
    mapping(bytes32 => SldRegistrationDetail) public sldRegistrationHistory;
    mapping(bytes32 => uint80[10]) public pricesAtRegistration;
    mapping(bytes32 => mapping(address => SldDiscountSettings)) public addressDiscounts;
    mapping(address => bool) public ValidSigner;
    mapping(bytes32 => uint256) public subdomainRegistrationNonce;

    IGlobalRegistrationRules public globalStrategy;

    IHandshakeSld public sld;
    IHandshakeTld public tld;

    /**
     * @return DOMAIN_SEPARATOR is used for eip712
     */
    bytes32 public DOMAIN_SEPARATOR;

    bytes32 private constant EIP712DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

    uint256 public gracePeriod;

    ICommitIntent public commitIntent;

    // New storage variables must be added at the END to maintain storage layout
    mapping(bytes32 => uint256) public sldCountPerTld;

    event DiscountSet(
        bytes32 indexed _tokenNamehash,
        address indexed _claimant,
        SldDiscountSettings _discount
    );

    event NewGracePeriod(uint256 _newGracePeriod);

    event ExpiredSldBurned(bytes32 indexed _parentNamehash, string _label, address burner);

    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the contract
     * @dev This function is called during contract deployment and sets up the contract's dependencies. It should only be called once.
     * @param _tld Address of the top level domain contract
     * @param _sld Address of the second level domain contract
     * @param _commitIntent Address of the commit intent contract
     * @param _oracle Address of the price oracle contract
     * @param _validator Address of the label validator contract
     * @param _globalRules Address of the global registration rules contract
     * @param _payoutWallet Address of the wallet for royalties
     * @param _owner Address of the contract owner
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
        gracePeriod = 30 days;
        ValidSigner[0xdA29bd6a46B89Cc5a5a404663524132D2f7Df10f] = true;
        _transferOwnership(_owner);

        DOMAIN_SEPARATOR = hashDomain();
    }

    function hashDomain() internal view returns (bytes32) {
        EIP712Domain memory eip712Domain = EIP712Domain({
            name: "Namebase",
            version: "1",
            chainId: block.chainid,
            verifyingContract: address(this)
        });

        return
            keccak256(
                abi.encodePacked(
                    EIP712DOMAIN_TYPEHASH,
                    keccak256(bytes(eip712Domain.name)),
                    keccak256(bytes(eip712Domain.version)),
                    eip712Domain.chainId,
                    eip712Domain.verifyingContract
                )
            );
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
    function registerWithCommit(
        string calldata _label,
        bytes32 _secret,
        uint256 _registrationLength,
        bytes32 _parentNamehash,
        address _recipient
    ) external payable {
        bytes32 sldNamehash = Namehash.getNamehash(_parentNamehash, _label);
        require(
            commitIntent.allowedCommit(sldNamehash, _secret, msg.sender),
            "No valid commit intent"
        );
        registerSld(_label, sldNamehash, _registrationLength, _parentNamehash, _recipient);

        unchecked {
            emit RegisterSld(
                _parentNamehash,
                _secret,
                _label,
                block.timestamp + (_registrationLength * 1 days)
            );
        }
    }

    function getRegistrationHash(address buyer, bytes32 subdomainHash)
        public
        view
        returns (bytes32)
    {
        uint256 nonce = subdomainRegistrationNonce[subdomainHash];

        return
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR,
                    keccak256(abi.encodePacked(buyer, subdomainHash, nonce))
                )
            );
    }

    function hash(EIP712Domain memory eip712Domain) internal view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    EIP712DOMAIN_TYPEHASH,
                    keccak256(bytes(eip712Domain.name)),
                    keccak256(bytes(eip712Domain.version)),
                    eip712Domain.chainId,
                    eip712Domain.verifyingContract
                )
            );
    }

    function checkSignatureValid(
        address buyer,
        bytes32 subdomainHash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public view returns (address) {
        bytes32 message = getRegistrationHash(buyer, subdomainHash);
        address signer = ecrecover(message, v, r, s);

        require(ValidSigner[signer], "invalid signature");
        return signer;
    }

    // Internal function that handles the core registration logic
    function _registerSldInternal(
        string calldata _label,
        bytes32 sldNamehash,
        uint256 _registrationLength,
        bytes32 _parentNamehash,
        address _recipient,
        bool returnFundsToRecipient
    ) private {
        require(canRegister(sldNamehash), "domain already registered");

        // Check if this is a new registration or re-registration of an expired domain
        bool isNewRegistration = sldRegistrationHistory[sldNamehash].RegistrationTime == 0;

        _recipient = _recipient == address(0) ? msg.sender : _recipient;
        sld.registerSld(_recipient, _parentNamehash, _label);

        require(labelValidator.isValidLabel(_label), "invalid label");

        ISldRegistrationStrategy strategy = sld.getRegistrationStrategy(_parentNamehash);
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

        addRegistrationDetails(sldNamehash, strategy, _parentNamehash, _label);

        sldRegistrationHistory[sldNamehash] = SldRegistrationDetail(
            uint72(block.timestamp),
            uint80(_registrationLength * 1 days),
            uint96(dollarPrice)
        );

        // Only increment count for new registrations, not re-registrations
        if (isNewRegistration) {
            unchecked {
                ++sldCountPerTld[_parentNamehash];
            }
        }

        uint256 weiValue = getWeiValueOfDollar();
        uint256 priceInWei = (weiValue * dollarPrice) / 1 ether;

        // Determine who receives the funds based on the flag
        address fundReceiver = returnFundsToRecipient ? _recipient : msg.sender;
        distributePrimaryFunds(fundReceiver, tld.ownerOf(uint256(_parentNamehash)), priceInWei);
    }

    // Private function for basic registration
    function registerSld(
        string calldata _label,
        bytes32 sldNamehash,
        uint256 _registrationLength,
        bytes32 _parentNamehash,
        address _recipient
    ) private {
        _registerSldInternal(
            _label,
            sldNamehash,
            _registrationLength,
            _parentNamehash,
            _recipient,
            false
        );
    }

    // Public function for signature-based registration with standard fund distribution
    function registerWithSignature(
        string calldata _label,
        uint256 _registrationLength,
        bytes32 _parentNamehash,
        address _recipient,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable {
        bytes32 sldNamehash = Namehash.getNamehash(_parentNamehash, _label);
        address signer = checkSignatureValid(msg.sender, sldNamehash, v, r, s);

        _registerSldInternal(
            _label,
            sldNamehash,
            _registrationLength,
            _parentNamehash,
            _recipient,
            false
        );

        unchecked {
            ++subdomainRegistrationNonce[sldNamehash];
            emit RegisterSld(
                _parentNamehash,
                bytes32(abi.encodePacked(signer)),
                _label,
                block.timestamp + (_registrationLength * 1 days)
            );
        }
    }

    // New public function for signature-based registration that returns funds to recipient
    function registerWithSignatureReturnFundsToRecipient(
        string calldata _label,
        uint256 _registrationLength,
        bytes32 _parentNamehash,
        address _recipient,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable {
        bytes32 sldNamehash = Namehash.getNamehash(_parentNamehash, _label);
        address signer = checkSignatureValid(msg.sender, sldNamehash, v, r, s);

        _registerSldInternal(
            _label,
            sldNamehash,
            _registrationLength,
            _parentNamehash,
            _recipient,
            true
        );

        unchecked {
            ++subdomainRegistrationNonce[sldNamehash];
            emit RegisterSld(
                _parentNamehash,
                bytes32(abi.encodePacked(signer)),
                _label,
                block.timestamp + (_registrationLength * 1 days)
            );
        }
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
        uint256 arrayLength = _discounts.length;
        require(_addresses.length == arrayLength, "array lengths do not match");

        for (uint256 i; i < arrayLength; ) {
            addressDiscounts[_parentNamehash][_addresses[i]] = _discounts[i];

            emit DiscountSet(_parentNamehash, _addresses[i], _discounts[i]);

            unchecked {
                ++i;
            }
        }
    }

    function burnSld(string calldata _label, bytes32 _parentNamehash) external {
        bytes32 sldNamehash = Namehash.getNamehash(_parentNamehash, _label);
        require(!canRegister(sldNamehash), "invalid domain");
        require(sld.ownerOf(uint256(sldNamehash)) == msg.sender, "only owner can burn");

        delete sldRegistrationHistory[sldNamehash];

        if (sldCountPerTld[_parentNamehash] > 0) {
            unchecked {
                --sldCountPerTld[_parentNamehash];
            }
        }

        sld.burnSld(sldNamehash);
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
        require(_registrationLength < 36500, "must be less than 100 years");
        bytes32 sldNamehash = Namehash.getNamehash(_parentNamehash, _label);

        require(!canRegister(sldNamehash), "invalid domain");

        SldRegistrationDetail storage detail = sldRegistrationHistory[sldNamehash];

        detail.RegistrationLength = detail.RegistrationLength + (_registrationLength * 1 days);

        address tldOwner = tld.ownerOf(uint256(_parentNamehash));

        uint256 priceInDollars = getRenewalPrice(
            msg.sender,
            _parentNamehash,
            _label,
            _registrationLength
        );

        require(
            globalStrategy.canRenew(
                msg.sender,
                _parentNamehash,
                _label,
                _registrationLength,
                priceInDollars + 1 // plus 1 wei for rounding issue
            ),
            "cannot renew"
        );

        uint256 weiValueOfDollar = getWeiValueOfDollar();

        uint256 priceInWei = (weiValueOfDollar * priceInDollars) / 1 ether;

        distributePrimaryFunds(msg.sender, tldOwner, priceInWei);

        emit RenewSld(_parentNamehash, _label, detail.RegistrationTime + detail.RegistrationLength);
    }

    function canRegister(bytes32 _namehash) private view returns (bool) {
        SldRegistrationDetail memory detail = sldRegistrationHistory[_namehash];
        return
            (detail.RegistrationTime + detail.RegistrationLength + gracePeriod) < block.timestamp;
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

    function updateGracePeriod(uint256 _gracePeriodInSeconds) public onlyOwner {
        gracePeriod = _gracePeriodInSeconds;
        emit NewGracePeriod(_gracePeriodInSeconds);
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
     * @notice Update the commit intent
     * @dev Might update this in the future to prevent frontrunning
     *
     * @param _commitIntent Address of the commit intent contract
     */
    function updateCommitIntent(ICommitIntent _commitIntent) public onlyOwner {
        commitIntent = _commitIntent;
    }

    /**
     * @notice Update a signer
     * @dev Might update this in the future to prevent frontrunning
     *
     * @param _signer Public address of the signer
     * @param _status Boolean to set the signer to
     */
    function updateSigner(address _signer, bool _status) public onlyOwner {
        ValidSigner[_signer] = _status;
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
        uint256 arrayLength = arr.length;

        for (uint256 i; i < arrayLength; ) {
            uint256 price = _strategy.getPriceInDollars(
                msg.sender,
                _parentNamehash,
                _label,
                (i + 1) * 365,
                false
            );

            uint256 annualPrice = price / (i + 1);

            // don't think that this is an issue. but just in case there is
            // some overflow exploit.. We need to check each year as user
            // can use custom registration contract
            require(annualPrice < type(uint80).max, "price too high");

            arr[i] = uint80(annualPrice);

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
        uint256 index;

        {
            uint256 registrationYears = (_registrationLength / 365); //get the annual rate

            registrationYears = registrationYears > 10 ? 10 : registrationYears;

            if (registrationYears > 10) {
                index = 9;
            } else if (registrationYears > 0) {
                index = registrationYears - 1;
            }
        }

        uint256 renewalCostPerAnnum = pricesAtRegistration[sldNamehash][index];

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
            renewalCostPerAnnum < globalStrategy.minimumDollarPrice() ||
                tld.ownerOf(uint256(_parentNamehash)) == _addr
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
        uint256 minPrice = (globalStrategy.minimumDollarPrice() * _registrationLength) / 365;

        if (tld.ownerOf(uint256(_parentNamehash)) == _addr) {
            return minPrice;
        } else {
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

            uint256 discount = (currentPrice * getCurrentDiscount(_parentNamehash, _addr, true)) /
                100;
            currentPrice = currentPrice - discount;

            return minPrice > currentPrice ? minPrice : currentPrice;
        }
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

    function initializeSldCount(bytes32 _tldNamehash, uint256 _count) external onlyOwner {
        sldCountPerTld[_tldNamehash] = _count;
    }

    /**
     * @notice Re-initialization function to set SLD counts from production data
     * @dev This function can only be called by the contract owner and is intended for post-upgrade initialization
     *      It sets the SLD counts for all TLDs based on the production data from Optimism mainnet
     */
    function reinitializeSldCounts() external onlyOwner {
        // Data from optimism-sld-counts.csv - using total_slds column
        sldCountPerTld[0x1e3f482b3363eb4710dae2cb2183128e272eafbe137f686851c1caea32502230] = 4720; // wallet
        sldCountPerTld[0xfb667b5dbbd33e7c0717051928f3b5eb9f4c4de9e1f1c14c71774773504711ca] = 558; // hns
        sldCountPerTld[0x4563ca3bedbc9c0da25528b63f193982105b26c193703c89f366f53ab1890599] = 221; // nb
        sldCountPerTld[0x909d89a6c97ebacfd8cd079f595a16b79cbcc508843b14d3d3cb1c97cc31a5fc] = 133; // lands
        sldCountPerTld[0x3435e492d3f50d8369d77b32373416ef6f34c50f0454c720b364a33611911a2d] = 84; // mfers
        sldCountPerTld[0x76d7696e5f1c1a57f8be29f6367f075ee954f9edab0bd4465015df26b575039c] = 81; // xn--qei
        sldCountPerTld[0xf74eb0c4f56e8d485674f1b0199276f3a9fef39ba856171c783bf87d9f1649f1] = 69; // d
        sldCountPerTld[0x973deb3041683362f73dd0512d1a2dff171188942f5b3aeea3744c76d68ab170] = 63; // nigeria
        sldCountPerTld[0xaeb80943d7970b602b395cbc8c7f1a6d98738aee6d23e7689d14efe266704067] = 61; // dapp
        sldCountPerTld[0xba7f75997c08b2dc328961a566cfeb7189fb0d0deec9465b8e185e8061e848ff] = 52; // hey
        sldCountPerTld[0x744b77150f688ac33ed9c0b172559f9c4ec7228d5c03da601862938298b7380d] = 37; // nostr
        sldCountPerTld[0x53a683e2ee4d9970e2394c6a5c77884114eb0624fb52a5257300d5992444e330] = 26; // musician
        sldCountPerTld[0x9090c5fffd8f17cfb6fd0aeedb8a0e169e9a2b336e25361cd859e863a3d5334c] = 26; // milady
        sldCountPerTld[0x51fd5b7854640e7aa91ebe46ffc2e6f9a7fd0a92affd67fea6a745b3bb409880] = 25; // isokay
        sldCountPerTld[0x86f0862d3547ad8b0e4356e668802c5a9d6bd11cc61ecaea28aa5bcc3713821c] = 23; // culer
        sldCountPerTld[0xf2fb775bc5b8dea6354e80838a0747ea5c8db0f02bb294ec3e4b69f00fbb62d4] = 19; // w3
        sldCountPerTld[0x9633bf5b45f659fb596a0fdfaa6a29afee5b0d4333aa973fcff790a0ed942175] = 19; // artist
        sldCountPerTld[0xeab9e720f8174bbed53d9e5c979274ff0eb695b7e5b70cd6d6119a63e38f31f9] = 19; // det0x
        sldCountPerTld[0xee8d9584585feb8e79a9742647bdf849f3fbe70421d7d52febf247616d0e5f41] = 17; // switzerland
        sldCountPerTld[0xa023b18e20bf66556a83b4606a1c8894256405b5f25fb05bf7965f0b85466e34] = 15; // bro
        sldCountPerTld[0xb3b754bdce9f792c4c4a00662246f65c2ebe5bbc0ba186595df1f4f90d5b9cf2] = 14; // vietnamese
        sldCountPerTld[0xcb4b3c7af7ef5e64ffb0bb12e458dd6bb8460a3e5d959fe04101fdf2428244b0] = 13; // xn--4zg1316p
        sldCountPerTld[0xa0c53c1cfbc8d6a7bfa07f94f2a5092c5e7063316c91fc946680d60fa4afff55] = 13; // smartass
        sldCountPerTld[0xf5e198c51185651928c1870e2365d229d433285755dd9f1c7b3a864c98dcbe49] = 13; // ok
        sldCountPerTld[0x580f9c36c91d470aeaa6763576c81643cc4b9537b23182e1a7e22a3109e262f0] = 12; // bx
        sldCountPerTld[0xe80a42e70da8f6f6c4d248f39a2bd85e686a424e3509d5df9eff3656405cff30] = 12; // pakistan
        sldCountPerTld[0xa2ac850ef102e75d355baa2ebba09f1c51d71e0f40a31b6eb8255abbc80a264a] = 11; // hodl
        sldCountPerTld[0x9dbbdd1b51eca6f68d5aab2b4310e73af3326ea489f2850744dbef78236db142] = 10; // collectable
        sldCountPerTld[0x3cfb81e2e3611fb3ed29841e125cf2016148d49603872817074c06855cee44e4] = 10; // runemaster
        sldCountPerTld[0xcb06e77803d6ce16a640291dfcbb8471964f1623ffb2cf1f347137348d9562b4] = 8; // bjk
        sldCountPerTld[0x46180856018b7da4f7e47f5f85f536f9cca9e417904cd2e18a0f592e766d8cbf] = 8; // shog
        sldCountPerTld[0x71d19cd4c084f97d87195abb313a3e826f844b542acf57d81205dea5c4b7fdaf] = 7; // intern
        sldCountPerTld[0xe72f51a547ab29bb59caf55f875c85d385963bd2189909b285cf2493639d67c9] = 7; // cop
        sldCountPerTld[0xd60131170097b5d5f4f88983a4b886e68986eaeb383452e7732378b9b649ac0e] = 6; // inweb3
        sldCountPerTld[0x029727bc599f53d5272268448507ea2497e3ee7aa5c3b3e1244f50821e8d174e] = 6; // xn--bh8h
        sldCountPerTld[0x33c525bca19fdf9d20e12eaa63e969a7250c9606ce8524b559c88d11767c18e9] = 4; // 3digitsclub
        sldCountPerTld[0xb63582a7f94ce3576ab283e9ddf255d845833639ab2705ca2dcf41d0e2775b1a] = 4; // uswap
        sldCountPerTld[0x435ab16cc0b5b3b35276de5442ef660b3a4e7893f5baa37a05b25dcac6832fec] = 3; // voiceweb
        sldCountPerTld[0x0078aa13664722e394f52750673f4aaea809975a74bc7d1f6a2176571483607b] = 3; // xn--6s9h
        sldCountPerTld[0x1360b1f397b030938042af8c8a0a1b36a69ed1ff434ff02b849830643e0ebe6f] = 3; // multi-pass
        sldCountPerTld[0x2f20e93027434dbe35bc979056df538f5e2985b2a39395ba4369e8c743b782e3] = 3; // lazy
        sldCountPerTld[0x7a67d72a5743a63bf16135e30639555499527e0a56f9949fc37a96de33632d91] = 2; // sounds-good
        sldCountPerTld[0xa65aae28ca24d54e765452982926d5f2141f4b401c2d255b43e63a77fb586182] = 2; // xbased
        sldCountPerTld[0xb1a92c416a686f0a895bb3a26a33047169852a1adde6a52b5c07dc994b5ee75f] = 2; // xn--7bi
        sldCountPerTld[0x5a5f95b00328eaeab44ef5705f1aff7590b46c70d447271da73f71d052afb882] = 2; // xn--to8h
        sldCountPerTld[0x118a0846c25bda90d39116f2944ff5621a7a050308446316ec30d98236031585] = 2; // xn--z38h
        sldCountPerTld[0x6257fad9615b42a8a3b98125bc84b0ac316860fedb4090a5d995fdd1791ae45e] = 2; // crashout
        sldCountPerTld[0x6c0c6202aaacd60983e04f10f04a66ca0b6cf9f5fd0b49953d0165e613fc0a19] = 1; // newyork-id
        sldCountPerTld[0x73016fa05231a533e8bfb5a5fca6efd998a9f12a341239b2b604e77fde48bf43] = 1; // optimism
        sldCountPerTld[0x51f00b28137ec2ca8668477ca152a059dfeecff3cb004657ac370fabd98e224d] = 1; // hhm
        sldCountPerTld[0xa66190da9965ae62afd81d58a1b50fd6e54560a099d783341cbd83613303653d] = 1; // rccg
        sldCountPerTld[0x9943f16f51dd82af77684f31df541ba127b31e90e3452d5852c313ef653fd6f0] = 1; // pizzalover
        sldCountPerTld[0xe88999de6221a62f670ad703106930ae18e47bd677890694ed39617bc83b331a] = 1; // fofar
        sldCountPerTld[0x93d4f055cbf38dca5fadae1a9abcf16a4f2d57b3a53d75db56d1dc0cc95bba31] = 1; // bittensor
        sldCountPerTld[0xeefbe0533da5f73efc22c553eac4dfa8d0f14933f00ac7ad48b5ad2d8fc78950] = 1; // lovely
        sldCountPerTld[0xf46229817a8e456f1eab0d2885f3d352f8cea7eed73c6eb8b8d1b8864372d5e8] = 1; // uwuai
        sldCountPerTld[0xeaa9a9d1de460e1322625a9a93de956cfa7161e10dc13529f59a91a5b056a3c1] = 1; // nigga
        // TLDs with 0 counts are already initialized to 0 by default, so no need to set them explicitly
    }

    /**
     * @notice Burns an expired SLD. Anyone can call this function for domains that have expired.
     * @dev This function checks that the domain has actually expired before allowing it to be burned.
     *      It doesn't require ownership verification since expired domains can't have a valid owner.
     * @param _label selected SLD label
     * @param _parentNamehash bytes32 representation of the top level domain
     */
    function burnExpiredSld(string calldata _label, bytes32 _parentNamehash) external {
        bytes32 sldNamehash = Namehash.getNamehash(_parentNamehash, _label);

        // Check that the domain exists in registration history
        SldRegistrationDetail memory detail = sldRegistrationHistory[sldNamehash];
        require(detail.RegistrationTime > 0, "domain not registered");

        // Check that the domain has expired (including grace period)
        require(
            detail.RegistrationTime + detail.RegistrationLength + gracePeriod < block.timestamp,
            "domain not expired"
        );

        // Delete registration history
        delete sldRegistrationHistory[sldNamehash];

        // Decrement the SLD count for the TLD
        if (sldCountPerTld[_parentNamehash] > 0) {
            unchecked {
                --sldCountPerTld[_parentNamehash];
            }
        }

        // Burn the SLD token
        sld.burnSld(sldNamehash);

        emit ExpiredSldBurned(_parentNamehash, _label, msg.sender);
    }

    /**
     * @notice Burns multiple expired SLDs for a single TLD. Anyone can call this function for domains that have expired.
     * @dev This function checks that each domain has actually expired before allowing it to be burned.
     *      It doesn't require ownership verification since expired domains can't have a valid owner.
     *      All labels must belong to the same parent TLD.
     * @param _labels Array of selected SLD labels to burn
     * @param _parentNamehash bytes32 representation of the top level domain
     */
    function bulkBurnExpiredSld(string[] calldata _labels, bytes32 _parentNamehash) external {
        require(_labels.length > 0, "no labels provided");
        require(_labels.length <= 100, "too many labels"); // Gas limit protection

        uint256 burnedCount = 0;

        for (uint256 i = 0; i < _labels.length; i++) {
            bytes32 sldNamehash = Namehash.getNamehash(_parentNamehash, _labels[i]);

            // Check that the domain exists in registration history
            SldRegistrationDetail memory detail = sldRegistrationHistory[sldNamehash];
            require(detail.RegistrationTime > 0, "domain not registered");

            // Check that the domain has expired (including grace period)
            require(
                detail.RegistrationTime + detail.RegistrationLength + gracePeriod < block.timestamp,
                "domain not expired"
            );

            // Delete registration history
            delete sldRegistrationHistory[sldNamehash];

            // Try to burn the SLD token if it exists
            try sld.ownerOf(uint256(sldNamehash)) returns (address) {
                // Token exists, try to burn it
                try sld.burnSld(sldNamehash) {
                    burnedCount++;
                    emit ExpiredSldBurned(_parentNamehash, _labels[i], msg.sender);
                } catch {
                    // If burn fails for any reason, revert
                    revert("failed to burn token");
                }
            } catch {
                // Token doesn't exist (already burned), just count it and emit event
                burnedCount++;
                emit ExpiredSldBurned(_parentNamehash, _labels[i], msg.sender);
            }
        }

        // Decrement the SLD count for the TLD by the number of burned domains
        if (sldCountPerTld[_parentNamehash] >= burnedCount) {
            unchecked {
                sldCountPerTld[_parentNamehash] -= burnedCount;
            }
        } else {
            sldCountPerTld[_parentNamehash] = 0;
        }
    }
}

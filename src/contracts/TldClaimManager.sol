// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "interfaces/IHandshakeTld.sol";
import "interfaces/ITldClaimManager.sol";
import "./HasLabelValidator.sol";
import {Namehash} from "utils/Namehash.sol";
import "src/contracts/HasUsdOracle.sol";
import "structs/EIP712Domain.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title Tld claim manager contract
 * @author Sam Ward
 * @notice This contract is for managing the TLDs that can be claimed
 *         TLD managers can add allowed TLDs that can be minted by address
 */
contract TldClaimManager is OwnableUpgradeable, ITldClaimManager, HasLabelValidator, HasUsdOracle {
    mapping(address => bool) public allowedTldManager;
    mapping(bytes32 => address) public tldClaimantMap;
    mapping(bytes32 => address) public tldProviderMap;

    IHandshakeTld public handshakeTldContract;
    address public handshakeWalletPayoutAddress;

    ISldRegistrationStrategy public defaultRegistrationStrategy;

    uint256 public mintPriceInDollars;

    // IMPORTANT: New storage variables must be added at the END to maintain storage layout
    ISldRegistrationManager public sldRegistrationManager;
    mapping(address => bool) public ValidSigner;

    /**
     * @return DOMAIN_SEPARATOR is used for eip712
     */
    bytes32 public DOMAIN_SEPARATOR;

    bytes32 private constant EIP712DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    constructor() {
        _disableInitializers();
    }

    function init(
        ILabelValidator _validator,
        address _owner,
        IHandshakeTld _tld,
        ISldRegistrationStrategy _strategy,
        IPriceOracle _oracle,
        uint256 _mintPriceInDollars,
        address _handshakeWalletPayoutAddress
    ) public initializer {
        labelValidator = _validator;
        handshakeTldContract = _tld;

        defaultRegistrationStrategy = _strategy;
        usdOracle = _oracle;
        mintPriceInDollars = _mintPriceInDollars;
        handshakeWalletPayoutAddress = _handshakeWalletPayoutAddress;
        _transferOwnership(_owner);

        DOMAIN_SEPARATOR = hashDomain();
    }

    function hashDomain() internal view returns (bytes32) {
        EIP712Domain memory eip712Domain = EIP712Domain({
            name: "TldClaimManager",
            version: "1",
            chainId: block.chainid,
            verifyingContract: address(this)
        });

        return keccak256(
            abi.encodePacked(
                EIP712DOMAIN_TYPEHASH,
                keccak256(bytes(eip712Domain.name)),
                keccak256(bytes(eip712Domain.version)),
                eip712Domain.chainId,
                eip712Domain.verifyingContract
            )
        );
    }

    function getBurnHash(address burner, bytes32 tldNamehash) public view returns (bytes32) {
        return
            keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, keccak256(abi.encodePacked(burner, tldNamehash))));
    }

    function checkSignatureValid(address burner, bytes32 tldNamehash, uint8 v, bytes32 r, bytes32 s)
        public
        view
        returns (address)
    {
        bytes32 message = getBurnHash(burner, tldNamehash);

        address signer = ecrecover(message, v, r, s);

        require(ValidSigner[signer], "invalid signature");
        return signer;
    }

    /**
     * @notice Helper function to check if an address can claim a TLD
     * @dev This function is public so that it can be used by UI if required.
     *
     * @param _addr address of the claimant
     * @param _namehash Namehash of the TLD label. Use namehash library.
     *
     * @return _canClaim Return bool value
     */
    function canClaim(address _addr, bytes32 _namehash) public view returns (bool _canClaim) {
        _canClaim = tldClaimantMap[_namehash] == _addr;
    }

    function setHandshakeTldContract(IHandshakeTld _tld) external onlyOwner {
        handshakeTldContract = _tld;
    }

    /**
     * @notice Set the SLD registration manager contract
     * @dev This function can only be called by the contract owner
     * @param _manager Address of the SLD registration manager contract
     */
    function setSldRegistrationManager(ISldRegistrationManager _manager) external onlyOwner {
        sldRegistrationManager = _manager;
    }

    /**
     * @notice Update a signer
     * @dev This function can only be run by the contract owner
     * @param _signer Public address of the signer
     * @param _status Boolean to set the signer to
     */
    function updateSigner(address _signer, bool _status) public onlyOwner {
        ValidSigner[_signer] = _status;
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
     * @notice Update the mint price in dollars
     * @dev Can be updated by contract owner
     * @param _priceInDollarDecimals Price in dollars
     */
    function updateMintPrice(uint256 _priceInDollarDecimals) public onlyOwner {
        mintPriceInDollars = _priceInDollarDecimals;
    }

    /**
     * @notice This function calls through to the TLD NFT contract and registers TLD NFT.
     * @dev Only whitelisted TLDs can be claimed/minted
     *
     * @param _domain string domain TLD
     */
    function claimTld(string calldata _domain, address _addr) public payable {
        bytes32 namehash = Namehash.getTldNamehash(_domain);

        require(canClaim(msg.sender, namehash), "not eligible to claim");

        if (mintPriceInDollars > 0 || msg.value > 0) {
            uint256 expectedEther = (usdOracle.getWeiValueOfDollar() * mintPriceInDollars) / 1 ether;
            require(msg.value >= expectedEther, "not enough ether");

            (bool result,) = handshakeWalletPayoutAddress.call{value: expectedEther}("");

            require(result, "transfer failed");
            // refund any extra ether
            if (expectedEther < msg.value) {
                unchecked {
                    // we already do a check that msg.value must be >= expectedEther
                    (result,) = msg.sender.call{value: msg.value - expectedEther}("");
                    require(result, "transfer failed");
                }
            }
        }

        handshakeTldContract.registerWithResolver(_addr, _domain, defaultRegistrationStrategy);

        delete tldClaimantMap[namehash];
        emit TldClaimed(msg.sender, uint256(namehash), _domain);
    }

    /**
     * @notice Burns a TLD if the caller is the owner, no SLDs exist for it, and signature is valid
     * @dev Requires the SldRegistrationManager to be set to check for existing SLDs and a valid signature
     * @param _domain The TLD domain to burn
     * @param v The recovery byte of the signature
     * @param r Half of the ECDSA signature pair
     * @param s Half of the ECDSA signature pair
     */
    function burnTld(string calldata _domain, uint8 v, bytes32 r, bytes32 s) external {
        bytes32 namehash = Namehash.getTldNamehash(_domain);
        uint256 tokenId = uint256(namehash);

        // Check that the caller is the owner of the TLD
        require(handshakeTldContract.ownerOf(tokenId) == msg.sender, "not TLD owner");

        // Check that the SLD registration manager is set
        require(address(sldRegistrationManager) != address(0), "SLD registration manager not set");

        // Check that no SLDs exist for this TLD
        require(sldRegistrationManager.sldCountPerTld(namehash) == 0, "SLDs exist for this TLD");

        // Verify the signature
        checkSignatureValid(msg.sender, namehash, v, r, s);

        // Call the burnTld function on the HandshakeTld contract
        handshakeTldContract.burnTld(tokenId);

        emit TldBurned(msg.sender, tokenId, _domain);
    }

    /**
     * @notice This function adds addresses / domains to whitelist. Only one address per TLD
     * @dev Can be removed from the whitelist by using address(0). Both arrays should be the same size
     *
     * @param _addr Addresses of the wallets allowed to claim
     * @param _domain string representation of the domains that will be claimed
     */
    function addTldAndClaimant(address[] calldata _addr, string[] calldata _domain) external onlyAuthorisedTldManager {
        uint256 arrayLength = _addr.length;
        require(arrayLength == _domain.length, "address and domain list should be the same length");

        bytes32 tldNamehash;

        for (uint256 i; i < arrayLength;) {
            require(labelValidator.isValidLabel(_domain[i]), "domain not valid");
            tldNamehash = Namehash.getTldNamehash(_domain[i]);
            tldClaimantMap[tldNamehash] = _addr[i];
            tldProviderMap[tldNamehash] = msg.sender;

            emit AllowedTldMintUpdate(_addr[i], msg.sender, _domain[i]);

            unchecked {
                ++i;
            }
        }
    }

    // just a place holder for when TLD expiries get added later.
    function tldExpiry(bytes32) public view virtual returns (uint256) {
        return type(uint64).max;
    }

    /**
     * @notice This function adds addresses that are allowed to add TLD claimers
     * @dev Only can be ran by the contract owner
     *
     * @param _addr Address of a wallet allowed to add TLD claimers
     * @param _allowed true/false. Wallets can be removed by using false
     */
    function updateAllowedTldManager(address _addr, bool _allowed) external onlyOwner {
        allowedTldManager[_addr] = _allowed;
        emit UpdateAllowedTldManager(_addr, _allowed);
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

    function getMintPriceInWei() external view returns (uint256) {
        return usdOracle.getWeiValueOfDollar() * (mintPriceInDollars / 1 ether);
    }

    modifier onlyAuthorisedTldManager() {
        require(allowedTldManager[msg.sender], "not authorised to add TLD");
        _;
    }
}

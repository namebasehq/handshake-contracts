// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "interfaces/IHandshakeTld.sol";
import "interfaces/ITldClaimManager.sol";
import "interfaces/ILabelValidator.sol";
import "./HasLabelValidator.sol";
import {Namehash} from "utils/Namehash.sol";
import "interfaces/IResolver.sol";
import "src/contracts/HasUsdOracle.sol";
import "forge-std/console.sol";

/**
 * @title Tld claim manager contract
 * @author Sam Ward
 * @notice This contract is for managing the TLDs that can be claimed
 *         TLD managers can add allowed TLDs that can be minted by address
 */
contract TldClaimManager is OwnableUpgradeable, ITldClaimManager, HasLabelValidator, HasUsdOracle {
    //TODO: remove bools to improve gas usage
    mapping(bytes32 => bool) public isNodeRegistered;
    mapping(address => bool) public allowedTldManager;
    mapping(bytes32 => address) public tldClaimantMap;
    mapping(bytes32 => address) public tldProviderMap;

    IHandshakeTld public handshakeTldContract;
    address public handshakeWalletPayoutAddress;

    ISldRegistrationStrategy public defaultRegistrationStrategy;

    uint256 public mintPriceInDollars;

    function init(
        ILabelValidator _validator,
        address _owner,
        IHandshakeTld _tld,
        ISldRegistrationStrategy _strategy,
        IPriceOracle _oracle,
        uint256 _mintPriceInDollars
    ) public initializer {
        labelValidator = _validator;
        handshakeTldContract = _tld;

        defaultRegistrationStrategy = _strategy;
        usdOracle = _oracle;
        mintPriceInDollars = _mintPriceInDollars;
        _transferOwnership(_owner);
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
        _canClaim = tldClaimantMap[_namehash] == _addr && !isNodeRegistered[_namehash];
    }

    function setHandshakeTldContract(IHandshakeTld _tld) external onlyOwner {
        handshakeTldContract = _tld;
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
    function claimTld(string calldata _domain, address _addr) external payable {
        bytes32 namehash = Namehash.getTldNamehash(_domain);
        uint256 expectedEther = usdOracle.getWeiValueOfDollar() * (mintPriceInDollars / 1 ether);

        require(canClaim(msg.sender, namehash), "not eligible to claim");
        require(msg.value >= expectedEther, "not enough ether");

        console.log("msg.value", msg.value);
        console.log("expectedEther", expectedEther);
        isNodeRegistered[namehash] = true;
        handshakeTldContract.registerWithResolver(_addr, _domain, defaultRegistrationStrategy);

        if (expectedEther < msg.value) {
            payable(msg.sender).transfer(msg.value - expectedEther);
        }

        emit TldClaimed(msg.sender, uint256(namehash), _domain);
    }

    /**
     * @notice This function adds addresses / domains to whitelist. Only one address per TLD
     * @dev Can be removed from the whitelist by using address(0). Both arrays should be the same size
     *
     * @param _addr Addresses of the wallets allowed to claim
     * @param _domain string representation of the domains that will be claimed
     */
    function addTldAndClaimant(address[] calldata _addr, string[] calldata _domain)
        external
        onlyAuthorisedTldManager
    {
        require(
            _addr.length == _domain.length,
            "address and domain list should be the same length"
        );

        bytes32 tldNamehash;

        for (uint256 i; i < _addr.length; ) {
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

    modifier onlyAuthorisedTldManager() {
        require(allowedTldManager[msg.sender], "not authorised to add TLD");
        _;
    }
}

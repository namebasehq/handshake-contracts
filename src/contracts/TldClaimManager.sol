// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "interfaces/IHandshakeTld.sol";
import "interfaces/ITldClaimManager.sol";
import "interfaces/ILabelValidator.sol";
import "./HasLabelValidator.sol";
import {Namehash} from "utils/Namehash.sol";

/**
 * @title Tld claim manager contract
 * @author Sam Ward
 * @notice This contract is for managing the TLDs that can be claimed
 *         TLD managers can add allowed TLDs that can be minted by address
 */
contract TldClaimManager is Ownable, ITldClaimManager, HasLabelValidator {
    //TODO: remove bools to improve gas usage
    mapping(bytes32 => bool) public isNodeRegistered;
    mapping(address => bool) public allowedTldManager;
    mapping(bytes32 => address) public tldClaimantMap;
    mapping(bytes32 => address) public tldProviderMap;

    IHandshakeTld public handshakeTldContract;

    event UpdateAllowedTldManager(address indexed _addr, bool _allowed);

    constructor(ILabelValidator _validator) HasLabelValidator(_validator) {}

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
     * @notice This function calls through to the TLD NFT contract and registers TLD NFT.
     * @dev Only whitelisted TLDs can be claimed/minted
     *
     * @param _domain string domain TLD
     */
    function claimTld(string calldata _domain) external {
        bytes32 namehash = Namehash.getTldNamehash(_domain);
        require(canClaim(msg.sender, namehash), "not eligible to claim");
        isNodeRegistered[namehash] = true;
        handshakeTldContract.register(msg.sender, _domain);
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
            tldNamehash = Namehash.getTldNamehash(_domain[i]);
            tldClaimantMap[tldNamehash] = _addr[i];
            tldProviderMap[tldNamehash] = msg.sender;
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

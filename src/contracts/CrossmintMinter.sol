// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "interfaces/ISldRegistrationManager.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

interface ISldRegistrationManager2 {
    function registerWithSignatureReturnFundsToRecipient(
        string calldata _label,
        uint256 _registrationLength,
        bytes32 _parentNamehash,
        address _recipient,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable;
}

contract CrossmintMinter is Ownable {
    ISldRegistrationManager2 public immutable registrar;

    mapping(address => bool) public isMinter;
    bool public isWhitelist;

    constructor(address _registrar) Ownable() {
        require(_registrar != address(0), "Invalid registrar address");
        registrar = ISldRegistrationManager2(_registrar);
    }

    function mint(
        string calldata _label,
        uint256 _registrationLength,
        bytes32 _parentNamehash,
        address _recipient,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable {
        require(isMinter[msg.sender] || !isWhitelist, "Not authorized");
        registrar.registerWithSignatureReturnFundsToRecipient{value: msg.value}(
            _label, _registrationLength, _parentNamehash, _recipient, v, r, s
        );
    }

    function updateMinter(address _minter, bool _value) external onlyOwner {
        isMinter[_minter] = _value;
    }

    function updateWhitelist(bool _isWhitelist) external onlyOwner {
        isWhitelist = _isWhitelist;
    }
}

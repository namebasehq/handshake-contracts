// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "interfaces/IHandshakeSld.sol";
import "interfaces/IHandshakeTld.sol";
import "interfaces/ILabelValidator.sol";
import "interfaces/ISldRegistrationManager.sol";
import "structs/SubdomainRegistrationDetail.sol";

contract MockSldRegistrationManager is ISldRegistrationManager {
    function registerSld(
        string calldata _label,
        bytes32 _secret,
        uint256 _registrationLength,
        bytes32 _parentNamehash,
        address _recipient
    ) external payable {}

    function renewSubdomain(bytes32 _subdomainHash, uint256 _registrationLength) external payable {}

    function getRenewalPricePerDay(bytes32 _parentNamehash, uint256 _registrationLength)
        public
        view
        returns (uint256)
    {
        require(false, "not implemented");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface IGlobalRegistrationRules is IERC165 {
    function canRegister(
        address _buyingAddress,
        bytes32 _parentNamehash,
        string calldata _label,
        uint256 _registrationLength,
        uint256 _dollarPrice
    ) external view returns (bool);
}

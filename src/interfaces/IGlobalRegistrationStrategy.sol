// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface IGlobalRegistrationStrategy is IERC165 {
    function canRegister(
        address _buyingAddress,
        bytes32 _parentNamehash,
        string calldata _label,
        uint256 _registrationLength,
        uint256 _dollarPrice
    ) external view returns (bool);
}
